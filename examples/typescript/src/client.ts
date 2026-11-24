// Sends RPCs to a SkirRPC service from the browser or Node.js.
//
// To run from the browser, run:
//   npm run server
// then visit:
//   http://localhost:8787/
//
// To run from Node.js, run:
//    npm run client-on-node
import { ServiceClient } from "skir-client";
import {
  AddUser,
  AddUserRequest,
  GetUser,
  GetUserRequest,
} from "../skirout/service";
import { TARZAN, User } from "../skirout/user";

const serviceClient = new ServiceClient("http://localhost:8787/myapi");

async function callService(): Promise<void> {
  console.log("Adding 2 users: John Doe and Tarzan");

  await serviceClient.invokeRemote(
    AddUser,
    AddUserRequest.create({
      user: User.create<"partial">({
        userId: 42,
        name: "John Doe",
      }),
    }),
  );

  await serviceClient.invokeRemote(
    AddUser,
    AddUserRequest.create({
      user: TARZAN,
    }),
  );

  console.log("Done");

  const foundUser = await serviceClient.invokeRemote(
    GetUser,
    GetUserRequest.create({
      userId: 123,
    }),
    "GET",
    // ^ note: POST would work too, but GET is more appropriate here
  );

  // Log the retrieved user (Tarzan)
  console.log(`Found user: ${foundUser.user}`);
}

callService();
