// Sends RPCs to the SkirRPC service. See cmd/start-service for how to start it.
//
// Run with:
//
//	go run ./cmd/call-service
//
// Make sure the service is running first (using cmd/start-service).

package main

import (
	"context"
	"fmt"

	skir "github.com/gepheum/skir-go-client"
	svc "github.com/gepheum/skir-go-example/skirout/service"
	user "github.com/gepheum/skir-go-example/skirout/user"
)

func main() {
	ctx := context.Background()
	client := skir.NewServiceClient("http://localhost:8787/myapi")
	defer client.Close()

	// Add two users.
	for _, u := range []user.User{
		user.User_builder().
			SetName("John Doe").
			SetPets(nil).
			SetQuote("Coffee is just a socially acceptable form of rage.").
			SetSubscriptionStatus(user.SubscriptionStatus_freeConst()).
			SetUserId(42).
			Build(),
		user.Tarzan_const(),
	} {
		_, err := skir.InvokeRemote(
			ctx,
			client,
			svc.AddUser(),
			svc.AddUserRequest_builder().SetUser(u).Build(),
		)
		if err != nil {
			panic(err)
		}
		fmt.Printf("Added user %q (id=%d)\n", u.Name(), u.UserId())
	}

	// Retrieve Tarzan.
	tarzan := user.Tarzan_const()
	resp, err := skir.InvokeRemote(
		ctx,
		client,
		svc.GetUser(),
		svc.GetUserRequest_builder().SetUserId(tarzan.UserId()).Build(),
	)
	if err != nil {
		panic(err)
	}
	if resp.User().IsPresent() {
		fmt.Printf("Got user: %v\n", user.User_serializer().ToJson(resp.User().Get(), skir.Readable{}))
	} else {
		fmt.Println("User not found")
	}
}
