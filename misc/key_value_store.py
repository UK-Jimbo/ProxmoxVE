from flask import Flask, request

app = Flask(__name__)
store = {}

@app.route('/get', methods=['GET'])
def get_key_value():
    key = request.args.get('key')
    if key in store:
        return store[key], 200
    return "Key not found", 404

@app.route('/set', methods=['POST'])
def set_key_value():
    data = request.get_json()
    if 'key' in data and 'value' in data:
        store[data['key']] = data['value']
        return "Key-value pair set successfully", 200
    return "Invalid data", 400

@app.route('/delete', methods=['DELETE'])
def delete_key_value():
    key = request.args.get('key')
    if key in store:
        del store[key]
        return "Key deleted successfully", 200
    return "Key not found", 404

@app.route('/list', methods=['GET'])
def list_key_values():
    if store:
        return "\n".join(f"{key}: {value}" for key, value in store.items()), 200
    return "No key-value pairs found", 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
