// Starts a SkirRPC service on http://localhost:8787/myapi
//
// Run with:
//
//	go run ./cmd/start-service
//
// Use ./cmd/call-service to send requests to this service.

package main

import (
	"context"
	"fmt"
	"net/http"
	"sync"

	skir "github.com/gepheum/skir-go-client"
	svc "github.com/gepheum/skir-go-example/skirout/service"
	user "github.com/gepheum/skir-go-example/skirout/user"
)

// userStore is a simple in-memory user store.
type userStore struct {
	mu       sync.RWMutex
	idToUser map[int32]user.User
}

func (s *userStore) getUser(
	_ context.Context,
	req svc.GetUserRequest,
	_ struct{},
) (svc.GetUserResponse, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	u, ok := s.idToUser[req.UserId()]
	if !ok {
		return svc.GetUserResponse_partialBuilder().SetUser_Absent().Build(), nil
	}
	return svc.GetUserResponse_partialBuilder().SetUser_Present(u).Build(), nil
}

func (s *userStore) addUser(
	_ context.Context,
	req svc.AddUserRequest,
	_ struct{},
) (svc.AddUserResponse, error) {
	if req.User().UserId() == 0 {
		return svc.AddUserResponse_partialBuilder().Build(),
			&skir.ServiceError{
				StatusCode: skir.HttpErrorCode_BadRequest,
				Message:    "user_id must be non-zero",
			}
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.idToUser == nil {
		s.idToUser = make(map[int32]user.User)
	}
	s.idToUser[req.User().UserId()] = req.User()
	return svc.AddUserResponse_partialBuilder().Build(), nil
}

func main() {
	store := &userStore{}

	b := skir.NewServiceBuilder[struct{}]()
	skir.AddMethod(b, svc.GetUser(), store.getUser)
	skir.AddMethod(b, svc.AddUser(), store.addUser)
	service := b.Build()

	fmt.Println("Listening on http://localhost:8787/myapi")
	http.HandleFunc("/myapi", func(w http.ResponseWriter, r *http.Request) {
		service.HandleRequestFromStandardLib(r, struct{}{}).ServeHttp(w)
	})
	if err := http.ListenAndServe(":8787", nil); err != nil {
		panic(err)
	}
}
