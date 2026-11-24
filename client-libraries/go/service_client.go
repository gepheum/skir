package skir_client

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
)

// RpcError is returned by [InvokeRemote] when the server responds with a
// non-2xx HTTP status code or when a network-level failure occurs.
type RpcError struct {
	// StatusCode is the HTTP status code returned by the server, or 0 for
	// network-level failures (e.g. DNS error, connection refused, timeout).
	StatusCode int
	// Message is the error description.
	Message string
}

func (e *RpcError) Error() string {
	if e.StatusCode != 0 {
		return fmt.Sprintf("rpc error %d: %s", e.StatusCode, e.Message)
	}
	return "rpc error: " + e.Message
}

// ─────────────────────────────────────────────────────────────────────────────
// ServiceClient
// ─────────────────────────────────────────────────────────────────────────────

// ServiceClient sends Skir RPC requests to a remote service.
type ServiceClient struct {
	serviceUrl     string
	defaultHeaders map[string]string
	httpClient     *http.Client
}

// ServiceClientOption is a functional option for NewServiceClient.
type ServiceClientOption func(*ServiceClient)

// WithDefaultHeader returns a ServiceClientOption that adds a default header
// sent with every request.
func WithDefaultHeader(key, value string) ServiceClientOption {
	return func(c *ServiceClient) {
		c.defaultHeaders[key] = value
	}
}

// WithHttpClient returns a ServiceClientOption that replaces the default HTTP
// client with the provided one, useful for testing with httptest servers or for
// custom transports (e.g. adding TLS configuration).
func WithHttpClient(client *http.Client) ServiceClientOption {
	return func(c *ServiceClient) {
		c.httpClient = client
	}
}

// NewServiceClient creates a ServiceClient that sends all requests to
// serviceUrl.
func NewServiceClient(serviceUrl string, opts ...ServiceClientOption) *ServiceClient {
	c := &ServiceClient{
		serviceUrl:     serviceUrl,
		defaultHeaders: make(map[string]string),
		httpClient:     &http.Client{},
	}
	for _, o := range opts {
		o(c)
	}
	return c
}

// Close releases idle connections held by the underlying HTTP client. The
// ServiceClient must not be used after Close returns.
func (c *ServiceClient) Close() {
	c.httpClient.CloseIdleConnections()
}

// ─────────────────────────────────────────────────────────────────────────────
// InvokeRemote
// ─────────────────────────────────────────────────────────────────────────────

// InvokeOption is a functional option for InvokeRemote.
type InvokeOption func(*invokeConfig)

type invokeConfig struct {
	extraHeaders map[string]string
}

// WithHeader returns an InvokeOption that adds an HTTP header for a single
// InvokeRemote call, overriding any default header with the same name.
func WithHeader(key, value string) InvokeOption {
	return func(cfg *invokeConfig) {
		if cfg.extraHeaders == nil {
			cfg.extraHeaders = make(map[string]string)
		}
		cfg.extraHeaders[key] = value
	}
}

// InvokeRemote sends req to the remote service and returns the deserialized
// response. The provided context controls the deadline and cancellation of the
// underlying HTTP request.
//
// Because Go generics do not allow generic methods on structs, InvokeRemote is
// a package-level function rather than a method on ServiceClient.
//
// Example:
//
//	client := skir_client.NewServiceClient("https://example.com/api")
//	defer client.Close()
//
//	resp, err := skir_client.InvokeRemote(ctx, client, MyMethod(), MyRequest{...})
func InvokeRemote[Req, Resp any](
	ctx context.Context,
	client *ServiceClient,
	method Method[Req, Resp],
	req Req,
	opts ...InvokeOption,
) (Resp, *RpcError) {
	cfg := &invokeConfig{}
	for _, o := range opts {
		o(cfg)
	}

	// Wire body: methodName:methodNumber::requestJson
	requestJson := method.RequestSerializer().ToJson(req)
	var bodyBuf strings.Builder
	bodyBuf.WriteString(method.Name())
	bodyBuf.WriteByte(':')
	bodyBuf.WriteString(strconv.FormatInt(method.Number(), 10))
	bodyBuf.WriteString("::")
	bodyBuf.WriteString(requestJson)

	httpReq, err := http.NewRequestWithContext(
		ctx,
		http.MethodPost,
		client.serviceUrl,
		bytes.NewBufferString(bodyBuf.String()),
	)
	if err != nil {
		var zero Resp
		return zero, &RpcError{Message: "failed to build request: " + err.Error()}
	}
	httpReq.Header.Set("Content-Type", "text/plain; charset=utf-8")

	for k, v := range client.defaultHeaders {
		httpReq.Header.Set(k, v)
	}
	for k, v := range cfg.extraHeaders {
		httpReq.Header.Set(k, v)
	}

	httpResp, err := client.httpClient.Do(httpReq)
	if err != nil {
		var zero Resp
		return zero, &RpcError{Message: "request failed: " + err.Error()}
	}
	defer httpResp.Body.Close()

	respBody, err := io.ReadAll(httpResp.Body)
	if err != nil {
		var zero Resp
		return zero, &RpcError{
			StatusCode: httpResp.StatusCode,
			Message:    "failed to read response: " + err.Error(),
		}
	}

	if httpResp.StatusCode < 200 || httpResp.StatusCode >= 300 {
		var zero Resp
		msg := fmt.Sprintf("HTTP status %d", httpResp.StatusCode)
		ct := strings.ToLower(httpResp.Header.Get("Content-Type"))
		if strings.Contains(ct, "text/plain") {
			msg += ": " + string(respBody)
		}
		return zero, &RpcError{
			StatusCode: httpResp.StatusCode,
			Message:    msg,
		}
	}

	result, err := method.ResponseSerializer().FromJson(string(respBody), KeepUnrecognizedValues{})
	if err != nil {
		var zero Resp
		return zero, &RpcError{
			StatusCode: httpResp.StatusCode,
			Message:    "failed to decode response: " + err.Error(),
		}
	}
	return result, nil
}
