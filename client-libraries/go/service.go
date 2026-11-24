package skir_client

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"

	"github.com/valyala/fastjson"
)

// RawResponse is the serialized response returned by Service.HandleRequest.
// Pass it directly to your HTTP framework's response writer.
type RawResponse struct {
	// Data is the response body.
	Data string
	// StatusCode is the HTTP status code.
	StatusCode int
	// ContentType is the value for the Content-Type header.
	ContentType string
}

// ServeHttp writes the raw response to an http.ResponseWriter.
func (r RawResponse) ServeHttp(w http.ResponseWriter) {
	w.Header().Set("Content-Type", r.ContentType)
	w.WriteHeader(r.StatusCode)
	fmt.Fprint(w, r.Data)
}

// ─────────────────────────────────────────────────────────────────────────────
// HttpErrorCode
// ─────────────────────────────────────────────────────────────────────────────

// HttpErrorCode is an HTTP error status code (4xx or 5xx).
type HttpErrorCode int

const (
	HttpErrorCode_BadRequest                    HttpErrorCode = 400
	HttpErrorCode_Unauthorized                  HttpErrorCode = 401
	HttpErrorCode_PaymentRequired               HttpErrorCode = 402
	HttpErrorCode_Forbidden                     HttpErrorCode = 403
	HttpErrorCode_NotFound                      HttpErrorCode = 404
	HttpErrorCode_MethodNotAllowed              HttpErrorCode = 405
	HttpErrorCode_NotAcceptable                 HttpErrorCode = 406
	HttpErrorCode_ProxyAuthenticationRequired   HttpErrorCode = 407
	HttpErrorCode_RequestTimeout                HttpErrorCode = 408
	HttpErrorCode_Conflict                      HttpErrorCode = 409
	HttpErrorCode_Gone                          HttpErrorCode = 410
	HttpErrorCode_LengthRequired                HttpErrorCode = 411
	HttpErrorCode_PreconditionFailed            HttpErrorCode = 412
	HttpErrorCode_ContentTooLarge               HttpErrorCode = 413
	HttpErrorCode_UriTooLong                    HttpErrorCode = 414
	HttpErrorCode_UnsupportedMediaType          HttpErrorCode = 415
	HttpErrorCode_RangeNotSatisfiable           HttpErrorCode = 416
	HttpErrorCode_ExpectationFailed             HttpErrorCode = 417
	HttpErrorCode_ImATeapot                     HttpErrorCode = 418
	HttpErrorCode_MisdirectedRequest            HttpErrorCode = 421
	HttpErrorCode_UnprocessableContent          HttpErrorCode = 422
	HttpErrorCode_Locked                        HttpErrorCode = 423
	HttpErrorCode_FailedDependency              HttpErrorCode = 424
	HttpErrorCode_TooEarly                      HttpErrorCode = 425
	HttpErrorCode_UpgradeRequired               HttpErrorCode = 426
	HttpErrorCode_PreconditionRequired          HttpErrorCode = 428
	HttpErrorCode_TooManyRequests               HttpErrorCode = 429
	HttpErrorCode_RequestHeaderFieldsTooLarge   HttpErrorCode = 431
	HttpErrorCode_UnavailableForLegalReasons    HttpErrorCode = 451
	HttpErrorCode_InternalServerError           HttpErrorCode = 500
	HttpErrorCode_NotImplemented                HttpErrorCode = 501
	HttpErrorCode_BadGateway                    HttpErrorCode = 502
	HttpErrorCode_ServiceUnavailable            HttpErrorCode = 503
	HttpErrorCode_GatewayTimeout                HttpErrorCode = 504
	HttpErrorCode_HttpVersionNotSupported       HttpErrorCode = 505
	HttpErrorCode_VariantAlsoNegotiates         HttpErrorCode = 506
	HttpErrorCode_InsufficientStorage           HttpErrorCode = 507
	HttpErrorCode_LoopDetected                  HttpErrorCode = 508
	HttpErrorCode_NotExtended                   HttpErrorCode = 510
	HttpErrorCode_NetworkAuthenticationRequired HttpErrorCode = 511
)

// ─────────────────────────────────────────────────────────────────────────────
// ServiceError
// ─────────────────────────────────────────────────────────────────────────────

// ServiceError is an error that carries an HTTP status code. Method
// implementations may return a *ServiceError to control the HTTP response sent
// back to the client. Any other error type is treated as an internal server
// error (HTTP 500).
type ServiceError struct {
	// StatusCode is the HTTP error status code.
	StatusCode HttpErrorCode
	// Message is a human-readable explanation that is included in the response
	// body.
	Message string
}

func (e *ServiceError) Error() string {
	if e.Message != "" {
		return fmt.Sprintf("service error %d: %s", e.StatusCode, e.Message)
	} else {
		return fmt.Sprintf("service error %d", e.StatusCode)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// MethodErrorInfo
// ─────────────────────────────────────────────────────────────────────────────

// MethodErrorInfo carries contextual information about an error that occurred
// while handling a method call. It is passed to the ErrorLogger and
// CanSendUnknownErrorMessage hooks in ServiceBuilder.
type MethodErrorInfo[RequestMeta any] struct {
	// Err is the error returned by the method implementation.
	Err error
	// MethodName is the name of the method that was invoked.
	MethodName string
	// RawRequest is the JSON-serialized request.
	RawRequest string
	// RequestMeta is the per-request metadata supplied by the HTTP handler.
	RequestMeta RequestMeta
}

// ─────────────────────────────────────────────────────────────────────────────
// ServiceBuilder
// ─────────────────────────────────────────────────────────────────────────────

// ServiceBuilder configures a [Service] and registers its method
// implementations. Call [ServiceBuilder.Build] to create a Service once all
// methods have been registered with [AddMethod].
//
// # Quick-start
//
// 1. Implement each method as a plain Go function:
//
//	func getUser(
//		_ context.Context,
//		req svc.GetUserRequest,
//		_ struct{},    // replace struct{} with your own metadata type if needed
//	) (svc.GetUserResponse, error) {
//		// ... your logic here ...
//	}
//
// Optional: to signal a structured error to the caller, you can return a
// [*ServiceError]:
//
//	return nil, &skir_client.ServiceError{
//		StatusCode: skir_client.HttpErrorCode_BadRequest,
//		Message:    "user name must not be empty",
//	}
//
// 2. Register all methods and build the service:
//
//	b := skir_client.NewServiceBuilder[struct{}]()
//	skir_client.AddMethod(b, svc.GetUser(), getUser)
//	skir_client.AddMethod(b, svc.AddUser(), addUser)
//	service := b.Build()
//
// 3. Wire the service into an HTTP handler:
//
//	http.HandleFunc("/myapi", func(w http.ResponseWriter, r *http.Request) {
//		service.HandleRequestFromStandardLib(r, struct{}{}).ServeHttp(w)
//	})
type ServiceBuilder[RequestMeta any] struct {
	// KeepUnrecognizedValues instructs the service to preserve fields from a
	// newer schema version that are not recognized by this server. Defaults to
	// false.
	KeepUnrecognizedValues bool

	// CanSendUnknownErrorMessage is called when a non-ServiceError is returned
	// by a method implementation. If it returns true, the raw error message is
	// included in the HTTP 500 response body; otherwise a generic
	// "internal server error" message is used. Defaults to always false, which
	// is the safe default for production services.
	CanSendUnknownErrorMessage func(MethodErrorInfo[RequestMeta]) bool

	// ErrorLogger is called for every error that occurs during request
	// handling. Defaults to writing a one-line message to stderr.
	ErrorLogger func(MethodErrorInfo[RequestMeta])

	// StudioAppJsUrl is the URL of the Skir Studio JavaScript bundle that is
	// served when the request body is empty or "studio".
	StudioAppJsUrl string

	byNum  map[int64]*serviceMethodEntry[RequestMeta]
	byName map[string]*serviceMethodEntry[RequestMeta]
}

// NewServiceBuilder creates a new ServiceBuilder with default values pre-filled.
func NewServiceBuilder[RequestMeta any]() *ServiceBuilder[RequestMeta] {
	return &ServiceBuilder[RequestMeta]{
		StudioAppJsUrl: defaultStudioAppJsUrl,
		ErrorLogger: func(info MethodErrorInfo[RequestMeta]) {
			fmt.Fprintf(os.Stderr, "skir: error in method %q: %v\n", info.MethodName, info.Err)
		},
		CanSendUnknownErrorMessage: func(MethodErrorInfo[RequestMeta]) bool { return false },
		byNum:                      make(map[int64]*serviceMethodEntry[RequestMeta]),
		byName:                     make(map[string]*serviceMethodEntry[RequestMeta]),
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

const defaultStudioAppJsUrl = "https://cdn.jsdelivr.net/npm/skir-studio/dist/skir-studio-standalone.js"

// Service dispatches Skir RPC requests to registered method implementations.
// Create one by calling Build on a ServiceBuilder.
//
// RequestMeta is the type of per-request metadata supplied by the HTTP handler
// (e.g. authenticated user identity, request-scoped logger). Use struct{} if
// your service does not need metadata.
type Service[RequestMeta any] struct {
	keepUnrecognizedValues     bool
	canSendUnknownErrorMessage func(MethodErrorInfo[RequestMeta]) bool
	errorLogger                func(MethodErrorInfo[RequestMeta])
	studioAppJsUrl             string
	byNum                      map[int64]*serviceMethodEntry[RequestMeta]
	byName                     map[string]*serviceMethodEntry[RequestMeta]
}

// serviceMethodEntry is a type-erased registration record for a single method.
type serviceMethodEntry[RequestMeta any] struct {
	name   string
	number int64
	doc    string
	// invoke deserializes the request, calls the implementation, and returns
	// the JSON-serialized response. If readable is true, the response JSON is
	// indented.
	invoke func(
		ctx context.Context,
		requestJson string,
		keepUnrecognized bool,
		readable bool,
		meta RequestMeta,
	) (string, error)
	requestTypeDescriptor  string // TypeDescriptor.AsJson()
	responseTypeDescriptor string // TypeDescriptor.AsJson()
}

// AddMethod registers a method implementation on the builder.
//
// Because Go generics do not allow generic methods, AddMethod is a
// package-level function rather than a method on ServiceBuilder.
//
// Returns an error if a method with the same number has already been
// registered.
func AddMethod[Req, Resp, RequestMeta any](
	b *ServiceBuilder[RequestMeta],
	method Method[Req, Resp],
	impl func(ctx context.Context, req Req, meta RequestMeta) (Resp, error),
) error {
	entry := &serviceMethodEntry[RequestMeta]{
		name:   method.Name(),
		number: method.Number(),
		doc:    method.Doc(),
		invoke: func(
			ctx context.Context,
			requestJson string,
			keepUnrecognized bool,
			readable bool,
			meta RequestMeta,
		) (string, error) {
			var req Req
			var err error
			if keepUnrecognized {
				req, err = method.RequestSerializer().FromJson(requestJson, KeepUnrecognizedValues{})
			} else {
				req, err = method.RequestSerializer().FromJson(requestJson)
			}
			if err != nil {
				return "", &ServiceError{StatusCode: HttpErrorCode_BadRequest, Message: "invalid request: " + err.Error()}
			}
			resp, err := impl(ctx, req, meta)
			if err != nil {
				return "", err
			}
			if readable {
				return method.ResponseSerializer().ToJson(resp, Readable{}), nil
			}
			return method.ResponseSerializer().ToJson(resp), nil
		},
		requestTypeDescriptor:  method.RequestSerializer().TypeDescriptor().AsJson(),
		responseTypeDescriptor: method.ResponseSerializer().TypeDescriptor().AsJson(),
	}

	if b.byNum == nil {
		b.byNum = make(map[int64]*serviceMethodEntry[RequestMeta])
		b.byName = make(map[string]*serviceMethodEntry[RequestMeta])
	}
	if _, exists := b.byNum[entry.number]; exists {
		return fmt.Errorf("skir: method number %d already registered", entry.number)
	}
	b.byNum[entry.number] = entry
	b.byName[entry.name] = entry
	return nil
}

// Build creates a Service from this builder.
func (b *ServiceBuilder[RequestMeta]) Build() *Service[RequestMeta] {
	return &Service[RequestMeta]{
		keepUnrecognizedValues:     b.KeepUnrecognizedValues,
		canSendUnknownErrorMessage: b.CanSendUnknownErrorMessage,
		errorLogger:                b.ErrorLogger,
		studioAppJsUrl:             b.StudioAppJsUrl,
		byNum:                      b.byNum,
		byName:                     b.byName,
	}
}

// HandleRequest processes a raw request body and returns a [RawResponse].
// Pass the result directly to [RawResponse.ServeHttp] to write the HTTP
// response.
//
// The body argument must be one of:
//   - Empty string or "studio": serves Skir Studio (the interactive browser UI).
//   - "list": returns a JSON list of all registered methods.
//   - A JSON object (starts with '{'): dispatched as a JSON-format RPC call.
//   - Any other string: dispatched as a colon-format RPC call
//     ("MethodName:number::requestJson" or "MethodName::requestJson").
//
// If you are using the standard Go HTTP library, prefer
// [Service.HandleRequestFromStandardLib], which extracts the body from an
// *http.Request automatically. HandleRequest is a lower-level alternative for
// integrating a SkirRPC service into a different web framework.
func (s *Service[RequestMeta]) HandleRequest(ctx context.Context, body string, meta RequestMeta) RawResponse {
	switch body {
	case "", "studio":
		return s.serveStudio()
	case "list":
		return s.serveList()
	}
	if strings.HasPrefix(body, "{") {
		return s.handleJsonRequest(ctx, body, meta)
	}
	return s.handleColonRequest(ctx, body, meta)
}

// HandleRequestFromStandardLib is like [HandleRequest] but reads the body from
// an *http.Request.
func (s *Service[RequestMeta]) HandleRequestFromStandardLib(r *http.Request, meta RequestMeta) RawResponse {
	var body string
	if r.Method == http.MethodGet {
		decoded, err := url.QueryUnescape(r.URL.RawQuery)
		if err != nil {
			return rawBadRequest("invalid query string encoding")
		}
		body = decoded
	} else {
		b, err := io.ReadAll(r.Body)
		if err != nil {
			return rawServerError("failed to read request body")
		}
		body = string(b)
	}
	return s.HandleRequest(r.Context(), body, meta)
}

// ─────────────────────────────────────────────────────────────────────────────
// Built-in endpoints
// ─────────────────────────────────────────────────────────────────────────────

func (s *Service[RequestMeta]) serveList() RawResponse {
	entries := make([]*serviceMethodEntry[RequestMeta], 0, len(s.byName))
	for _, e := range s.byName {
		entries = append(entries, e)
	}

	var sb strings.Builder
	sb.WriteString(`{"methods": [`)
	for i, e := range entries {
		if i > 0 {
			sb.WriteByte(',')
		}
		sb.WriteString("\n  {\"method\":")
		writeJsonEscapedString(e.name, &sb)
		sb.WriteString(",\"number\":")
		sb.WriteString(strconv.FormatInt(e.number, 10))
		sb.WriteString(",\"request\":")
		sb.WriteString(e.requestTypeDescriptor)
		sb.WriteString(",\"response\":")
		sb.WriteString(e.responseTypeDescriptor)
		if e.doc != "" {
			sb.WriteString(",\"doc\":")
			writeJsonEscapedString(e.doc, &sb)
		}
		sb.WriteByte('}')
	}
	if len(entries) > 0 {
		sb.WriteByte('\n')
	}
	sb.WriteString("]}")
	return RawResponse{
		Data:        sb.String(),
		StatusCode:  http.StatusOK,
		ContentType: "application/json",
	}
}

const studioHtmlTemplate = `<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>RPC Studio</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns=%%22http://www.w3.org/2000/svg%%22 viewBox=%%220 0 100 100%%22><text y=%%22.9em%%22 font-size=%%2290%%22>🐙</text></svg>">
    <script src="%s"></script>
  </head>
  <body style="margin: 0; padding: 0;">
    <skir-studio-app></skir-studio-app>
  </body>
</html>
`

func (s *Service[RequestMeta]) serveStudio() RawResponse {
	return RawResponse{
		Data:        fmt.Sprintf(studioHtmlTemplate, htmlEscapeAttr(s.studioAppJsUrl)),
		StatusCode:  http.StatusOK,
		ContentType: "text/html; charset=utf-8",
	}
}

func htmlEscapeAttr(s string) string {
	s = strings.ReplaceAll(s, "&", "&amp;")
	s = strings.ReplaceAll(s, `"`, "&#34;")
	s = strings.ReplaceAll(s, "<", "&lt;")
	s = strings.ReplaceAll(s, ">", "&gt;")
	return s
}

// ─────────────────────────────────────────────────────────────────────────────
// Wire format handlers
// ─────────────────────────────────────────────────────────────────────────────

// handleJsonRequest handles the {"method": ..., "request": ...} wire format.
// This format always returns readable (indented) JSON.
// The "method" field must be either a JSON string (name lookup) or a JSON
// integer (number lookup).
func (s *Service[RequestMeta]) handleJsonRequest(ctx context.Context, body string, meta RequestMeta) RawResponse {
	v, err := fastjson.Parse(body)
	if err != nil {
		return rawBadRequest("bad request: invalid JSON")
	}
	methodVal := v.Get("method")
	if methodVal == nil {
		return rawBadRequest("bad request: missing 'method' field in JSON")
	}
	var entry *serviceMethodEntry[RequestMeta]
	switch methodVal.Type() {
	case fastjson.TypeNumber:
		number, numErr := methodVal.Int64()
		if numErr != nil {
			return rawBadRequest("bad request: 'method' number is invalid")
		}
		entry = s.byNum[number]
		if entry == nil {
			return rawBadRequest(fmt.Sprintf("bad request: method not found: %d", number))
		}
	case fastjson.TypeString:
		methodBytes, _ := methodVal.StringBytes()
		methodStr := string(methodBytes)
		entry = s.byName[methodStr]
		if entry == nil {
			return rawBadRequest("bad request: method not found: " + methodStr)
		}
	default:
		return rawBadRequest("bad request: 'method' field must be a string or integer")
	}
	requestVal := v.Get("request")
	if requestVal == nil {
		return rawBadRequest("bad request: missing 'request' field in JSON")
	}
	requestJson := string(requestVal.MarshalTo(nil))
	return s.invokeEntry(ctx, entry, requestJson, s.keepUnrecognizedValues, true /* readable */, meta)
}

// handleColonRequest handles the name:number:format:body wire format.
// If number is provided, lookup is by number (name is decorative).
// If number is absent, lookup is by name.
func (s *Service[RequestMeta]) handleColonRequest(ctx context.Context, body string, meta RequestMeta) RawResponse {
	// Split into exactly 4 parts; the body part may itself contain colons.
	parts := strings.SplitN(body, ":", 4)
	if len(parts) != 4 {
		return rawBadRequest("bad request: invalid request format")
	}
	nameStr, numberStr, format, requestJson := parts[0], parts[1], parts[2], parts[3]

	var entry *serviceMethodEntry[RequestMeta]
	if numberStr == "" {
		entry = s.byName[nameStr]
		if entry == nil {
			return rawBadRequest("bad request: method not found: " + nameStr)
		}
	} else {
		number, convErr := strconv.ParseInt(numberStr, 10, 64)
		if convErr != nil {
			return rawBadRequest("bad request: can't parse method number")
		}
		entry = s.byNum[number]
		if entry == nil {
			return rawBadRequest(fmt.Sprintf("bad request: method not found: %s; number: %d", nameStr, number))
		}
	}

	if requestJson == "" {
		requestJson = "{}"
	}
	readable := format == "readable"
	return s.invokeEntry(ctx, entry, requestJson, s.keepUnrecognizedValues, readable, meta)
}

// invokeEntry calls the registered implementation and wraps the result.
func (s *Service[RequestMeta]) invokeEntry(
	ctx context.Context,
	entry *serviceMethodEntry[RequestMeta],
	requestJson string,
	keepUnrecognized bool,
	readable bool,
	meta RequestMeta,
) RawResponse {
	responseJson, err := entry.invoke(ctx, requestJson, keepUnrecognized, readable, meta)
	if err == nil {
		return RawResponse{
			Data:        responseJson,
			StatusCode:  http.StatusOK,
			ContentType: "application/json",
		}
	}

	info := MethodErrorInfo[RequestMeta]{
		Err:         err,
		MethodName:  entry.name,
		RawRequest:  requestJson,
		RequestMeta: meta,
	}
	s.errorLogger(info)

	if svcErr, ok := errors.AsType[*ServiceError](err); ok {
		msg := svcErr.Message
		if msg == "" {
			msg = http.StatusText(int(svcErr.StatusCode))
		}
		return RawResponse{
			Data:        msg,
			StatusCode:  int(svcErr.StatusCode),
			ContentType: "text/plain; charset=utf-8",
		}
	}

	msg := "server error"
	if s.canSendUnknownErrorMessage(info) {
		msg = "server error: " + err.Error()
	}
	return rawServerError(msg)
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

func rawBadRequest(msg string) RawResponse {
	return RawResponse{
		Data:        msg,
		StatusCode:  http.StatusBadRequest,
		ContentType: "text/plain; charset=utf-8",
	}
}

func rawServerError(msg string) RawResponse {
	return RawResponse{
		Data:        msg,
		StatusCode:  http.StatusInternalServerError,
		ContentType: "text/plain; charset=utf-8",
	}
}
