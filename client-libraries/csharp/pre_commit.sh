#!/bin/bash

set -e

dotnet build SkirClient.csproj -warnaserror
dotnet test SkirClientTest/SkirClientTest.csproj
