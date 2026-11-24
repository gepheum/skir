// Starts a SkirRPC service at http://localhost:8787/?myapi
//
// Run with:
//   npm run server
//
// Visit http://localhost:8787/ in your browser to send RPCs to the service.
import express, { Request, Response } from "express";
import path from "path";
import { Service, installServiceOnExpressApp } from "skir-client";
import {
  AddUser,
  AddUserRequest,
  AddUserResponse,
  GetUser,
  GetUserRequest,
  GetUserResponse,
} from "../skirout/service";
import { User } from "../skirout/user";

const app = express();
const port = 8787;

app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
  res.header("Access-Control-Allow-Headers", "*");
  if (req.method === "OPTIONS") {
    res.sendStatus(200);
  } else {
    next();
  }
});

app.use(express.static(path.join(__dirname, "../../static")));

app.get("/", (req: Request, res: Response) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

class MyService {
  async addUser(
    req: AddUserRequest,
    // Add these parameters if you need to access the Express request/response
    // objects (e.g., for headers, cookies, etc.)
    reqMeta: Request,
  ): Promise<AddUserResponse> {
    const userId = req.user.userId;
    if (userId === 0) {
      throw new Error("User ID cannot be 0");
    }
    this.users[req.user.userId] = req.user;
    return AddUserResponse.create({});
  }

  async getUser(req: GetUserRequest): Promise<GetUserResponse> {
    const user = this.users[req.userId];
    if (user) {
      return GetUserResponse.create({ user: user });
    } else {
      return GetUserResponse.DEFAULT;
    }
  }

  private readonly users: { [id: string]: User } = {};
}

const myService = new MyService();

installServiceOnExpressApp(
  app,
  "/myapi",
  new Service({
    // Optional service configuration goes here
  })
    .addMethod(AddUser, MyService.prototype.addUser.bind(myService))
    .addMethod(GetUser, MyService.prototype.getUser.bind(myService)),
  express.text,
  express.json,
);

app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}/`);
});
