# Noir circuit that verifies a PS256 signature over a Open Banking (currently only Revolut) payment JWT and extracts the sort code, currency code, and currency amount

## Test circuit with Noir

1. Simply run `nargo test` in the root directory 

## Run circuit from JS

1. Compile circuit
```
cd ./scripts && ./compile.sh
```

2. Navigate to JS directory
```
cd ../js/src
```

3. Run JS code and view logged witness
```
node index.js
```
