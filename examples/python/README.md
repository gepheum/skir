# Skir Python example

Example showing how to use skir's [Python code generator](https://github.com/gepheum/skir-python-gen) in a project.

## Build and run the example

```shell
# Download this repository
git clone https://github.com/gepheum/skir-python-example.git

cd skir-python-example

# Install dependencies
pip install -r requirements.txt

# Run Skir-to-Python codegen
npx skir gen

python snippets.py
```

### Start a SkirRPC service

The example includes three different framework implementations. Choose one:

#### Flask
From one process, run:
```shell
python start_service_flask.py
```

#### FastAPI
From one process, run:
```shell
uvicorn start_service_fastapi:app --host localhost --port 8787
```

#### Litestar
From one process, run:
```shell
litestar --app start_service_starlite:app run --host localhost --port 8787
```

#### Call the service
From another process, run:
```shell
python call_service.py
```
