import { SplitCodeExample } from '@/components/split-code-example'

const skirCode = `struct WhatToWearRequest {
  temperature_celsius: float32;
  raining: bool;
}

struct WhatToWearResponse {
  bottom_outfit: string;
  sunglasses: bool;
}

method WhatToWear(WhatToWearRequest):
    WhatToWearResponse  = 770862;`

const codeExamples = {
  typescript: `import { ServiceClient } from "skir-client";
import { WhatToWear, WhatToWearRequest, WhatToWearResponse }
    from "../skirout/outfit_picker";

const client = new ServiceClient("http://localhost:8080/api");

const response: WhatToWearResponse = await client.invokeRemote(
  WhatToWear,
  WhatToWearRequest.create({
    temperatureCelsius: 25,
    raining: false,
  }),
);

if (response.sunglasses) {
  console.log("Don't forget your sunglasses 😎");
}`,

  python: `from skirout.outfit_picker_skir
    import WhatToWear, WhatToWearRequest, WhatToWearResponse

import skir

service_client = skir.ServiceClient("http://localhost:8080/api")

response: WhatToWearResponse = service_client.invoke_remote(
    WhatToWear,
    WhatToWearRequest(
        temperature_celsius=25,
        raining=False,
    ),
)

if (response.sunglasses):
    print("Don't forget your sunglasses 😎")`,

  cpp: `#include "httplib.h"
#include "skirout/outfit_picker.h"
#include "skir.h"

using ::skirout_outfit_picker::WhatToWear;
using ::skirout_outfit_picker::WhatToWearRequest;
using ::skirout_outfit_picker::WhatToWearResponse;

std::unique_ptr<skir::service::Client> client =
    skir::service::MakeHttplibClient(
        std::make_unique<httplib::Client>("localhost", 8080),
        "/api");

const WhatToWearRequest request = {
    .raining = false,
    .temperature_celsius = 25,
};

const absl::StatusOr<WhatToWearResponse> response =
    InvokeRemote(*client, WhatToWear(), request);

if (response.ok() && response->sunglasses) {
  std::cout << "Don't forget your sunglasses 😎\\n";
}`,

  kotlin: `import build.skir.service.ServiceClient
import skirout.outfit_picker.WhatToWear
import skirout.outfit_picker.WhatToWearRequest
import skirout.outfit_picker.WhatToWearResponse

val serviceClient = ServiceClient("http://localhost:8080/api")

val response: WhatToWearResponse = serviceClient.invokeRemote(
    WhatToWear,
    WhatToWearRequest(
        temperatureCelcius = 25,
        raining = false,
    ),
)

if (response.sunglasses) {
    println("Don't forget your sunglasses 😎")
}`,

  moonbit: `let client = @client.service_client::new("http://localhost:8080/api")

let response = @client.service_client::invoke_remote(
  client,
  @skirout_outfit_picker.what_to_wear_method(),
  @skirout_outfit_picker.WhatToWearRequest::new(
    temperature_celsius=25.0,
    raining=false,
  ),
)

if response.sunglasses {
  println("Don't forget your sunglasses 😎")
}`,

  java: `import build.skir.service.ServiceClient;
import skirout.outfit_picker.WhatToWearRequest;
import skirout.outfit_picker.WhatToWearResponse;
import skirout.outfit_picker.Methods;

final ServiceClient serviceClient =
    new ServiceClient("http://localhost:8080/api");

final WhatToWearResponse response =
    serviceClient.invokeRemoteBlocking(
        Methods.WHAT_TO_WEAR,
        WhatToWearRequest.builder()
            .setRaining(false)
            .setTemperatureCelsius(25)
            .build());

if (response.sunglasses()) {
  System.out.println("Don't forget your sunglasses 😎");
}`,

  csharp: `using SkirClient;
using Skirout_OutfitPicker;

var client = new ServiceClient("http://localhost:8080/api");

var response = client.InvokeRemote(
  Methods.WhatToWear,
  new WhatToWearRequest
  {
    TemperatureCelsius = 25,
    Raining = false,
  }
);

if (response.Sunglasses)
{
  Console.WriteLine("Don't forget your sunglasses 😎");
}`,

  dart: `import 'package:skir_client/skir_client.dart' as skir;
import 'package:your_project/skirout/outfit_picker.dart';

final serviceClient =
    skir.ServiceClient('http://localhost:8080/api');

final response: WhatToWearResponse = await serviceClient
    .wrap(whatToWearMethod)
    .invoke(
      WhatToWearRequest(
        temperatureCelsius: 25,
        raining: false,
      )
    );

if (response.sunglasses) {
  print("Don't forget your sunglasses 😎");
}`,

  swift: `import Foundation
import MyLib
import SkirClient

let client = try SkirClient.ServiceClient(serviceUrl: "http://localhost:8080/api")

let response = try await client.invokeRemote(
  Skir.WhatToWear,
  request: Skir.WhatToWearRequest.partial(
    temperatureCelsius: 25,
    raining: false
  )
)

if response.sunglasses {
  print("Don't forget your sunglasses 😎")
}`,

  rust: `use skir_client::ServiceClient;
use skirout::outfit_picker::{what_to_wear, WhatToWearRequest};

let client = ServiceClient::new("http://localhost:8080/api").unwrap();

let response = client
    .invoke_remote(
        what_to_wear(),
        &WhatToWearRequest {
            temperature_celsius: 25.0,
            raining: false,
            _unrecognized: None,
        },
        &[],
    )
    .unwrap();

if response.sunglasses {
    println!("Don't forget your sunglasses 😎");
}`,

  go: `import (
    "context"
    "fmt"
    skir "github.com/gepheum/skir-go-client"
    op "github.com/my-org/my-project/skirout/outfit_picker"
)

client := skir.NewServiceClient("http://localhost:8080/api")
defer client.Close()

response, err := skir.InvokeRemote(
    context.Background(),
    client,
    op.WhatToWear(),
    op.WhatToWearRequest_builder().
        SetRaining(false).
        SetTemperatureCelsius(25).
        Build(),
)
if err != nil {
    panic(err)
}
if response.Sunglasses() {
    fmt.Println("Don't forget your sunglasses 😎")
}`,

  elixir: `alias Skir.Generated.OutfitPickerSkir
alias OutfitPickerSkir.WhatToWearRequest

client = Skir.RPC.ServiceClient.new!("http://localhost:8080/api")

{:ok, response} =
  OutfitPickerSkir.what_to_wear(
    client,
    WhatToWearRequest.new(
      temperature_celsius: 25.0,
      raining: false
    )
  )

if response.sunglasses do
  IO.puts("Don't forget your sunglasses 😎")
end`,
}

export function RpcExample() {
  return <SplitCodeExample skirCode={skirCode} codeExamples={codeExamples} />
}
