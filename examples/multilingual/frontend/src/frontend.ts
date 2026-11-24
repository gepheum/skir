import { ServiceClient } from "skir-client";
import { Greet, GreetRequest, GreetResponse } from "../skirout/api.js";

const nameInput = document.getElementById("nameInput") as HTMLInputElement;
const sendBtn = document.getElementById("sendBtn") as HTMLButtonElement;
// const resultDiv = document.getElementById("result") as HTMLDivElement;

// Initialize Skir Service Client
// Point to the Skir dispatcher endpoint on the backend
const client = new ServiceClient("http://localhost:8080/skir");

sendBtn.addEventListener("click", async () => {
  const name = nameInput.value;

  const request = GreetRequest.create({
    name: name,
    temperatureC: 22,
    sunny: true,
  });

  const response =
    await client.invokeRemote(Greet, request);
  for (const action of response.actions) {
    performAction(action);
  }
});

function performAction(_: GreetResponse.Action) {}
