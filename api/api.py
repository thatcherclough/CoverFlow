import flask
from flask import jsonify
import apple_music

data_file_path = "./data.json"

app = flask.Flask(__name__)
app.config["DEBUG"] = True


@app.route('/api', methods=['GET'])
def api():
    ret = {"message": "CoverFlow API"}
    return jsonify(ret)


@app.route('/api/apple_music/key', methods=['GET'])
def key():
    key = apple_music.generateKey(data_file_path)

    ret = None
    if key == None:
        ret = {"error": "Could not generate API key"}
    else:
        ret = {"key": key}
    return jsonify(ret)


app.run(host="0.0.0.0")
