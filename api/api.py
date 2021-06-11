import flask
from flask import jsonify
from flask import request
import apple_music
import spotify

data_file_path = "./data.json"

app = flask.Flask(__name__)
app.config["DEBUG"] = True


@app.route("/api", methods=["GET"])
def api():
    ret = {"message": "CoverFlow API"}
    return jsonify(ret), 200


@app.route("/api/apple_music/key", methods=["GET"])
def key():
    key = apple_music.generateKey(data_file_path)

    ret = None
    if key == None:
        ret = {"error": "Could not generate key"}
    else:
        ret = {"key": key}
    return jsonify(ret), 200


@app.route("/api/spotify/swap", methods=["POST"])
def swap():
    if ("access_code" in request.args) & ("code_verifier" in request.args):
        access_code = request.args["access_code"]
        code_verifier = request.args["code_verifier"]

        swap = spotify.swap(data_file_path=data_file_path,
                            access_code=access_code, code_verifier=code_verifier)

        ret = None
        if swap == None:
            ret = {"error": "Could not get access and refresh tokens"}
        else:
            ret = swap
        return jsonify(ret)
    else:
        ret = {"error": "Missing parameters"}
        return jsonify(ret), 200


@app.route("/api/spotify/refresh", methods=["POST"])
def refresh():
    if "refresh_token" in request.args:
        refresh_token = request.args["refresh_token"]

        refresh = spotify.refresh(
            data_file_path=data_file_path, refresh_token=refresh_token)

        ret = None
        if refresh == None:
            ret = {"error": "Could not refresh"}
        else:
            ret = refresh
        return jsonify(ret)
    else:
        ret = {"error": "Missing parameters"}
        return jsonify(ret), 200


app.run(host="0.0.0.0")
