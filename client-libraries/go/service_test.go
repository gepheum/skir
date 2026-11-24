package skir_client

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// ─────────────────────────────────────────────────────────────────────────────
// Helpers shared by all service tests
// ─────────────────────────────────────────────────────────────────────────────

// echoMethod is a string→string method whose implementation simply returns its
// input unchanged.
var echoMethod = NewMethod(
	"Echo",
	1001,
	StringSerializer(),
	StringSerializer(),
	"Echoes the request",
)

// reverseMethod is a string→string method whose implementation reverses the
// input string.
var reverseMethod = NewMethod(
	"Reverse",
	1002,
	StringSerializer(),
	StringSerializer(),
	"Reverses the request string",
)

// failWithServiceError simulates a domain error.
var failMethod = NewMethod(
	"Fail",
	1003,
	StringSerializer(),
	StringSerializer(),
	"Always returns a ServiceError",
)

// failUnknownMethod simulates an unexpected error.
var failUnknownMethod = NewMethod(
	"FailUnknown",
	1004,
	StringSerializer(),
	StringSerializer(),
	"Always returns an unknown error",
)

// newTestService creates a Service[struct{}] with echMethod, reverseMethod and
// failMethod all registered.
func newTestService(opts ...ServiceBuilder[struct{}]) *Service[struct{}] {
	b := NewServiceBuilder[struct{}]()
	if len(opts) > 0 {
		if opts[0].KeepUnrecognizedValues {
			b.KeepUnrecognizedValues = true
		}
		if opts[0].CanSendUnknownErrorMessage != nil {
			b.CanSendUnknownErrorMessage = opts[0].CanSendUnknownErrorMessage
		}
		if opts[0].ErrorLogger != nil {
			b.ErrorLogger = opts[0].ErrorLogger
		}
		if opts[0].StudioAppJsUrl != "" {
			b.StudioAppJsUrl = opts[0].StudioAppJsUrl
		}
	}
	AddMethod(b, echoMethod, func(_ context.Context, req string, _ struct{}) (string, error) {
		return req, nil
	})
	AddMethod(b, reverseMethod, func(_ context.Context, req string, _ struct{}) (string, error) {
		runes := []rune(req)
		for i, j := 0, len(runes)-1; i < j; i, j = i+1, j-1 {
			runes[i], runes[j] = runes[j], runes[i]
		}
		return string(runes), nil
	})
	AddMethod(b, failMethod, func(_ context.Context, req string, _ struct{}) (string, error) {
		return "", &ServiceError{StatusCode: HttpErrorCode_NotFound, Message: req}
	})
	AddMethod(b, failUnknownMethod, func(_ context.Context, req string, _ struct{}) (string, error) {
		return "", errors.New("something went wrong internally")
	})
	return b.Build()
}

// httpTestServer wraps newTestService in an httptest.Server.
func httpTestServer(t *testing.T, opts ...ServiceBuilder[struct{}]) (*httptest.Server, *Service[struct{}]) {
	t.Helper()
	svc := newTestService(opts...)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "failed to read body", http.StatusInternalServerError)
			return
		}
		resp := svc.HandleRequest(r.Context(), string(body), struct{}{})
		resp.ServeHttp(w)
	}))
	t.Cleanup(srv.Close)
	return srv, svc
}

// ─────────────────────────────────────────────────────────────────────────────
// RawResponse.ServeHttp
// ─────────────────────────────────────────────────────────────────────────────

func TestRawResponse_ServeHttp(t *testing.T) {
	rr := httptest.NewRecorder()
	resp := RawResponse{Data: `{"ok":true}`, StatusCode: 201, ContentType: "application/json"}
	resp.ServeHttp(rr)

	if rr.Code != 201 {
		t.Errorf("status = %d, want 201", rr.Code)
	}
	if got := rr.Header().Get("Content-Type"); got != "application/json" {
		t.Errorf("Content-Type = %q, want application/json", got)
	}
	if got := rr.Body.String(); got != `{"ok":true}` {
		t.Errorf("body = %q, want {\"ok\":true}", got)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// ServiceError
// ─────────────────────────────────────────────────────────────────────────────

func TestServiceError_Error_withMessage(t *testing.T) {
	err := &ServiceError{StatusCode: 403, Message: "forbidden"}
	want := "service error 403: forbidden"
	if got := err.Error(); got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestServiceError_Error_noMessage(t *testing.T) {
	err := &ServiceError{StatusCode: 500}
	want := "service error 500"
	if got := err.Error(); got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Service – built-in endpoints
// ─────────────────────────────────────────────────────────────────────────────

func TestService_HandleRequest_studio_empty(t *testing.T) {
	s := newTestService()
	resp := s.HandleRequest(context.Background(), "", struct{}{})

	if resp.StatusCode != http.StatusOK {
		t.Errorf("status = %d, want 200", resp.StatusCode)
	}
	if !strings.Contains(resp.ContentType, "text/html") {
		t.Errorf("ContentType = %q, want text/html", resp.ContentType)
	}
	if !strings.Contains(resp.Data, "<html") {
		t.Error("expected HTML content")
	}
	if !strings.Contains(resp.Data, "skir-studio") {
		t.Error("expected skir-studio script tag in response")
	}
}

func TestService_HandleRequest_studio_keyword(t *testing.T) {
	s := newTestService()
	resp := s.HandleRequest(context.Background(), "studio", struct{}{})

	if resp.StatusCode != http.StatusOK {
		t.Errorf("status = %d, want 200", resp.StatusCode)
	}
	if !strings.Contains(resp.ContentType, "text/html") {
		t.Errorf("ContentType = %q, want text/html", resp.ContentType)
	}
}

func TestService_HandleRequest_studio_customJSURL(t *testing.T) {
	customURL := "https://my-cdn.example.com/studio.js"
	s := newTestService(ServiceBuilder[struct{}]{StudioAppJsUrl: customURL})
	resp := s.HandleRequest(context.Background(), "studio", struct{}{})

	if !strings.Contains(resp.Data, customURL) {
		t.Errorf("response body does not contain custom URL %q", customURL)
	}
}

func TestService_HandleRequest_list(t *testing.T) {
	s := newTestService()
	resp := s.HandleRequest(context.Background(), "list", struct{}{})

	if resp.StatusCode != http.StatusOK {
		t.Errorf("status = %d, want 200", resp.StatusCode)
	}
	if !strings.Contains(resp.ContentType, "application/json") {
		t.Errorf("ContentType = %q, want application/json", resp.ContentType)
	}

	var wrapper struct {
		Methods []struct {
			Method   string          `json:"method"`
			Number   int64           `json:"number"`
			Doc      string          `json:"doc"`
			Request  json.RawMessage `json:"request"`
			Response json.RawMessage `json:"response"`
		} `json:"methods"`
	}
	if err := json.Unmarshal([]byte(resp.Data), &wrapper); err != nil {
		t.Fatalf("failed to parse list JSON: %v\nbody: %s", err, resp.Data)
	}

	wantNames := []string{"Echo", "Fail", "FailUnknown", "Reverse"}
	if len(wrapper.Methods) != len(wantNames) {
		t.Fatalf("got %d methods, want %d", len(wrapper.Methods), len(wantNames))
	}
	gotNames := make(map[string]bool)
	for _, m := range wrapper.Methods {
		gotNames[m.Method] = true
	}
	for _, want := range wantNames {
		if !gotNames[want] {
			t.Errorf("method %q not found in list response", want)
		}
	}

	// Echo should have number 1001 and non-empty doc.
	var echoEntry *struct {
		Method   string          `json:"method"`
		Number   int64           `json:"number"`
		Doc      string          `json:"doc"`
		Request  json.RawMessage `json:"request"`
		Response json.RawMessage `json:"response"`
	}
	for i := range wrapper.Methods {
		if wrapper.Methods[i].Method == "Echo" {
			echoEntry = &wrapper.Methods[i]
			break
		}
	}
	if echoEntry == nil {
		t.Fatal("Echo method not found")
	}
	if echoEntry.Number != 1001 {
		t.Errorf("Echo number = %d, want 1001", echoEntry.Number)
	}
	if echoEntry.Doc != "Echoes the request" {
		t.Errorf("Echo doc = %q, want %q", echoEntry.Doc, "Echoes the request")
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Service – JSON object wire format
// ─────────────────────────────────────────────────────────────────────────────

func TestService_HandleRequest_jsonFormat_byName(t *testing.T) {
	s := newTestService()
	body := `{"method":"Echo","request":"hello"}`
	resp := s.HandleRequest(context.Background(), body, struct{}{})

	if resp.StatusCode != http.StatusOK {
		t.Errorf("status = %d, want 200\nbody: %s", resp.StatusCode, resp.Data)
	}
	// JSON object format always returns readable (indented) JSON.
	// The response is a JSON-encoded string "hello".
	var result string
	if err := json.Unmarshal([]byte(resp.Data), &result); err != nil {
		t.Fatalf("failed to parse response: %v\nbody: %s", err, resp.Data)
	}
	if result != "hello" {
		t.Errorf("response = %q, want %q", result, "hello")
	}
}

func TestService_HandleRequest_jsonFormat_byNumber(t *testing.T) {
	s := newTestService()
	body := `{"method":1002,"request":"abc"}`
	resp := s.HandleRequest(context.Background(), body, struct{}{})

	if resp.StatusCode != http.StatusOK {
		t.Errorf("status = %d, want 200\nbody: %s", resp.StatusCode, resp.Data)
	}
	var result string
	if err := json.Unmarshal([]byte(resp.Data), &result); err != nil {
		t.Fatalf("failed to parse response: %v\nbody: %s", err, resp.Data)
	}
	if result != "cba" {
		t.Errorf("response = %q, want %q", result, "cba")
	}
}

func TestService_HandleRequest_jsonFormat_unknownMethod(t *testing.T) {
	s := newTestService()
	body := `{"method":"NotExist","request":"hi"}`
	resp := s.HandleRequest(context.Background(), body, struct{}{})

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("status = %d, want 400", resp.StatusCode)
	}
}

func TestService_HandleRequest_jsonFormat_missingMethodField(t *testing.T) {
	s := newTestService()
	resp := s.HandleRequest(context.Background(), `{"request":"hi"}`, struct{}{})
	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("status = %d, want 400", resp.StatusCode)
	}
}

func TestService_HandleRequest_jsonFormat_serviceError(t *testing.T) {
	s := newTestService()
	body := `{"method":"Fail","request":"not found message"}`
	resp := s.HandleRequest(context.Background(), body, struct{}{})

	if resp.StatusCode != http.StatusNotFound {
		t.Errorf("status = %d, want 404", resp.StatusCode)
	}
	if !strings.Contains(resp.ContentType, "text/plain") {
		t.Errorf("ContentType = %q, want text/plain", resp.ContentType)
	}
	if resp.Data != "not found message" {
		t.Errorf("error body = %q, want %q", resp.Data, "not found message")
	}
}

func TestService_HandleRequest_jsonFormat_unknownError_hides_message(t *testing.T) {
	var loggedErrors []MethodErrorInfo[struct{}]
	s := newTestService(ServiceBuilder[struct{}]{
		ErrorLogger: func(info MethodErrorInfo[struct{}]) {
			loggedErrors = append(loggedErrors, info)
		},
	})
	resp := s.HandleRequest(context.Background(), `{"method":"FailUnknown","request":"x"}`, struct{}{})

	if resp.StatusCode != http.StatusInternalServerError {
		t.Errorf("status = %d, want 500", resp.StatusCode)
	}
	if strings.Contains(resp.Data, "internally") {
		t.Error("internal error message should not be leaked to client by default")
	}
	if len(loggedErrors) != 1 {
		t.Errorf("expected 1 logged error, got %d", len(loggedErrors))
	}
}

func TestService_HandleRequest_jsonFormat_unknownError_exposes_message(t *testing.T) {
	s := newTestService(ServiceBuilder[struct{}]{
		CanSendUnknownErrorMessage: func(MethodErrorInfo[struct{}]) bool { return true },
		ErrorLogger:                func(MethodErrorInfo[struct{}]) {}, // suppress stderr
	})
	resp := s.HandleRequest(context.Background(), `{"method":"FailUnknown","request":"x"}`, struct{}{})

	if resp.StatusCode != http.StatusInternalServerError {
		t.Errorf("status = %d, want 500", resp.StatusCode)
	}
	if !strings.Contains(resp.Data, "something went wrong internally") {
		t.Errorf("expected error message in body, got %q", resp.Data)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Service – colon-delimited wire format
// ─────────────────────────────────────────────────────────────────────────────

func TestService_HandleRequest_colonFormat_dense(t *testing.T) {
	s := newTestService()
	// Dense format: name:number::jsonBody  (format field is empty)
	resp := s.HandleRequest(context.Background(), `Echo:1001::"world"`, struct{}{})

	if resp.StatusCode != http.StatusOK {
		t.Errorf("status = %d, want 200\nbody: %s", resp.StatusCode, resp.Data)
	}
	var result string
	if err := json.Unmarshal([]byte(resp.Data), &result); err != nil {
		t.Fatalf("failed to parse response: %v\nbody: %s", err, resp.Data)
	}
	if result != "world" {
		t.Errorf("response = %q, want %q", result, "world")
	}
}

func TestService_HandleRequest_colonFormat_readable(t *testing.T) {
	s := newTestService()
	resp := s.HandleRequest(context.Background(), `Echo:1001:readable:"hi"`, struct{}{})

	if resp.StatusCode != http.StatusOK {
		t.Errorf("status = %d, want 200\nbody: %s", resp.StatusCode, resp.Data)
	}
	var result string
	if err := json.Unmarshal([]byte(resp.Data), &result); err != nil {
		t.Fatalf("failed to parse response: %v\nbody: %s", err, resp.Data)
	}
	if result != "hi" {
		t.Errorf("response = %q, want %q", result, "hi")
	}
}

func TestService_HandleRequest_colonFormat_nameOnly(t *testing.T) {
	// Number field is empty — lookup falls back to name.
	s := newTestService()
	resp := s.HandleRequest(context.Background(), `Echo:::"test"`, struct{}{})

	if resp.StatusCode != http.StatusOK {
		t.Errorf("status = %d, want 200\nbody: %s", resp.StatusCode, resp.Data)
	}
	var result string
	if err := json.Unmarshal([]byte(resp.Data), &result); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}
	if result != "test" {
		t.Errorf("response = %q, want %q", result, "test")
	}
}

func TestService_HandleRequest_colonFormat_numberOnly(t *testing.T) {
	// Name field is empty — lookup by number only.
	s := newTestService()
	resp := s.HandleRequest(context.Background(), `:1001::"test"`, struct{}{})

	if resp.StatusCode != http.StatusOK {
		t.Errorf("status = %d, want 200\nbody: %s", resp.StatusCode, resp.Data)
	}
}

func TestService_HandleRequest_colonFormat_nameIsDecorativeLookupByNumber(t *testing.T) {
	s := newTestService()
	// Name says "Echo" (1001) but number says 1002 (Reverse) — number wins.
	resp := s.HandleRequest(context.Background(), `Echo:1002::"test"`, struct{}{})

	if resp.StatusCode != http.StatusOK {
		t.Errorf("status = %d, want 200\nbody: %s", resp.StatusCode, resp.Data)
	}
	var result string
	if err := json.Unmarshal([]byte(resp.Data), &result); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}
	// Reverse of "test" is "tset".
	if result != "tset" {
		t.Errorf("response = %q, want %q", result, "tset")
	}
}

func TestService_HandleRequest_colonFormat_unknownMethod(t *testing.T) {
	s := newTestService()
	resp := s.HandleRequest(context.Background(), `NoSuchMethod:::"x"`, struct{}{})

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("status = %d, want 400\nbody: %s", resp.StatusCode, resp.Data)
	}
}

func TestService_HandleRequest_colonFormat_invalidJSON(t *testing.T) {
	s := newTestService()
	resp := s.HandleRequest(context.Background(), `Echo:1001::not-json`, struct{}{})

	if resp.StatusCode != http.StatusBadRequest {
		t.Errorf("status = %d, want 400\nbody: %s", resp.StatusCode, resp.Data)
	}
}

func TestService_HandleRequest_colonFormat_bodyContainsColons(t *testing.T) {
	// Ensure SplitN(4) correctly handles colons in the JSON body.
	s := newTestService()
	// The request is the string "a:b:c" — which contains colons.
	resp := s.HandleRequest(context.Background(), `Echo:1001::"a:b:c"`, struct{}{})

	if resp.StatusCode != http.StatusOK {
		t.Errorf("status = %d, want 200\nbody: %s", resp.StatusCode, resp.Data)
	}
	var result string
	if err := json.Unmarshal([]byte(resp.Data), &result); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}
	if result != "a:b:c" {
		t.Errorf("response = %q, want %q", result, "a:b:c")
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Service – AddMethod duplicate number/name
// ─────────────────────────────────────────────────────────────────────────────

func TestService_AddMethod_duplicateNumberReturnsError(t *testing.T) {
	b := NewServiceBuilder[struct{}]()
	if err := AddMethod(b, echoMethod, func(_ context.Context, req string, _ struct{}) (string, error) {
		return req, nil
	}); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// Register a different method name but same number.
	dupMethod := NewMethod("AnotherName", 1001, StringSerializer(), StringSerializer(), "")
	err := AddMethod(b, dupMethod, func(_ context.Context, req string, _ struct{}) (string, error) {
		return req, nil
	})
	if err == nil {
		t.Error("expected error for duplicate method number, got nil")
	}
}

func TestService_AddMethod_duplicateNameIsAllowed(t *testing.T) {
	b := NewServiceBuilder[struct{}]()
	if err := AddMethod(b, echoMethod, func(_ context.Context, req string, _ struct{}) (string, error) {
		return req, nil
	}); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// Same name, different number — should succeed.
	dupMethod := NewMethod("Echo", 9999, StringSerializer(), StringSerializer(), "")
	if err := AddMethod(b, dupMethod, func(_ context.Context, req string, _ struct{}) (string, error) {
		return "new impl", nil
	}); err != nil {
		t.Errorf("unexpected error for duplicate method name: %v", err)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Service – request metadata
// ─────────────────────────────────────────────────────────────────────────────

func TestService_RequestMeta_passedToImpl(t *testing.T) {
	type Meta struct{ UserID string }
	b := NewServiceBuilder[Meta]()
	var capturedMeta Meta
	m := NewMethod("WhoAmI", 5001, StringSerializer(), StringSerializer(), "")
	AddMethod(b, m, func(_ context.Context, _ string, meta Meta) (string, error) {
		capturedMeta = meta
		return meta.UserID, nil
	})
	s := b.Build()
	resp := s.HandleRequest(context.Background(), `WhoAmI:5001::"ignored"`, Meta{UserID: "alice"})
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200\nbody: %s", resp.StatusCode, resp.Data)
	}
	if capturedMeta.UserID != "alice" {
		t.Errorf("meta.UserID = %q, want alice", capturedMeta.UserID)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// ServiceClient + Service – integration (via httptest.Server)
// ─────────────────────────────────────────────────────────────────────────────

func TestServiceClient_InvokeRemote_success(t *testing.T) {
	srv, _ := httpTestServer(t)
	client := NewServiceClient(srv.URL)
	defer client.Close()

	result, err := InvokeRemote(context.Background(), client, echoMethod, "integration test")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result != "integration test" {
		t.Errorf("response = %q, want %q", result, "integration test")
	}
}

func TestServiceClient_InvokeRemote_reverseMethod(t *testing.T) {
	srv, _ := httpTestServer(t)
	client := NewServiceClient(srv.URL)
	defer client.Close()

	result, err := InvokeRemote(context.Background(), client, reverseMethod, "skir")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result != "riks" {
		t.Errorf("response = %q, want %q", result, "riks")
	}
}

func TestServiceClient_InvokeRemote_serviceError(t *testing.T) {
	srv, _ := httpTestServer(t, ServiceBuilder[struct{}]{
		ErrorLogger: func(MethodErrorInfo[struct{}]) {}, // suppress stderr
	})
	client := NewServiceClient(srv.URL)
	defer client.Close()

	_, err := InvokeRemote(context.Background(), client, failMethod, "thing not found")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	var rpcErr *RpcError
	if !errors.As(err, &rpcErr) {
		t.Fatalf("expected *RpcError, got %T: %v", err, err)
	}
	if rpcErr.StatusCode != http.StatusNotFound {
		t.Errorf("StatusCode = %d, want 404", rpcErr.StatusCode)
	}
	wantMsg := "HTTP status 404: thing not found"
	if rpcErr.Message != wantMsg {
		t.Errorf("Message = %q, want %q", rpcErr.Message, wantMsg)
	}
}

func TestServiceClient_InvokeRemote_unknownServerError(t *testing.T) {
	srv, _ := httpTestServer(t, ServiceBuilder[struct{}]{
		ErrorLogger: func(MethodErrorInfo[struct{}]) {},
	})
	client := NewServiceClient(srv.URL)
	defer client.Close()

	_, err := InvokeRemote(context.Background(), client, failUnknownMethod, "x")
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	var rpcErr *RpcError
	if !errors.As(err, &rpcErr) {
		t.Fatalf("expected *RpcError, got %T: %v", err, err)
	}
	if rpcErr.StatusCode != http.StatusInternalServerError {
		t.Errorf("StatusCode = %d, want 500", rpcErr.StatusCode)
	}
}

func TestServiceClient_WithDefaultHeader(t *testing.T) {
	var receivedHeader string
	extra := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		receivedHeader = r.Header.Get("X-Custom")
		fmt.Fprint(w, `"ok"`)
	}))
	defer extra.Close()

	client := NewServiceClient(extra.URL, WithDefaultHeader("X-Custom", "my-value"))
	defer client.Close()

	InvokeRemote(context.Background(), client, echoMethod, "x") //nolint:errcheck
	if receivedHeader != "my-value" {
		t.Errorf("X-Custom header = %q, want %q", receivedHeader, "my-value")
	}
}

func TestServiceClient_WithHeader_perCall(t *testing.T) {
	var receivedHeader string
	extra := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		receivedHeader = r.Header.Get("X-Per-Call")
		fmt.Fprint(w, `"ok"`)
	}))
	defer extra.Close()

	client := NewServiceClient(extra.URL)
	defer client.Close()

	InvokeRemote(context.Background(), client, echoMethod, "x", WithHeader("X-Per-Call", "call-value")) //nolint:errcheck
	if receivedHeader != "call-value" {
		t.Errorf("X-Per-Call header = %q, want %q", receivedHeader, "call-value")
	}
}

func TestServiceClient_ContextCancellation(t *testing.T) {
	// A server that blocks indefinitely.
	blocked := make(chan struct{})
	blockingSrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		<-blocked
	}))
	defer blockingSrv.Close()
	defer close(blocked)

	client := NewServiceClient(blockingSrv.URL)
	defer client.Close()

	ctx, cancel := context.WithCancel(context.Background())
	cancel() // cancel immediately

	_, err := InvokeRemote(ctx, client, echoMethod, "x")
	if err == nil {
		t.Fatal("expected error due to cancelled context, got nil")
	}
	var rpcErr *RpcError
	if !errors.As(err, &rpcErr) {
		t.Fatalf("expected *RpcError, got %T: %v", err, err)
	}
	if rpcErr.StatusCode != 0 {
		t.Errorf("expected StatusCode 0 for network error, got %d", rpcErr.StatusCode)
	}
}

func TestServiceClient_Close(t *testing.T) {
	srv, _ := httpTestServer(t)
	client := NewServiceClient(srv.URL)
	// Should not panic.
	client.Close()
}

// ─────────────────────────────────────────────────────────────────────────────
// RpcError
// ─────────────────────────────────────────────────────────────────────────────

func TestRpcError_Error_withStatusCode(t *testing.T) {
	err := &RpcError{StatusCode: 404, Message: "not found"}
	want := "rpc error 404: not found"
	if got := err.Error(); got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestRpcError_Error_networkFailure(t *testing.T) {
	err := &RpcError{StatusCode: 0, Message: "request failed: dial tcp: connection refused"}
	if !strings.HasPrefix(err.Error(), "rpc error: ") {
		t.Errorf("unexpected error format: %q", err.Error())
	}
}
