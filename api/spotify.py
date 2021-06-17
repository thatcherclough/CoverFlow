import requests
import base64
import six
import json


def create_header(client_id, client_secret):
    auth_header = base64.b64encode(
        six.text_type(client_id + ":" + client_secret).encode("ascii")
    )
    return {"Authorization": "Basic %s" % auth_header.decode("ascii")}


def swap(data_file_path, access_code, code_verifier):
    try:
        with open(data_file_path) as file:
            json_data = json.load(file)

            if "spotify" in json_data:
                spotify_data = dict(json_data["spotify"])

                if ("client_id" in spotify_data) & ("client_secret" in spotify_data) & ("redirect_uri" in spotify_data):
                    client_id = spotify_data["client_id"]
                    client_secret = spotify_data["client_id"]
                    redirect_uri = spotify_data["redirect_uri"]

                    url = "https://accounts.spotify.com/api/token"
                    header = create_header(
                        client_id=client_id, client_secret=client_secret)
                    body = {
                        "client_id": client_id,
                        "grant_type": "authorization_code",
                        "redirect_uri": redirect_uri,
                        "scope": "user-read-currently-playing",
                        "code_verifier": code_verifier,
                        "code": access_code
                    }
                    request = requests.post(url=url, headers=header, data=body)
                    try:
                        return request.json()
                    except json.decoder.JSONDecodeError:
                        return None
                else:
                    return None
            else:
                return None
    except FileNotFoundError:
        return None


def refresh(data_file_path, refresh_token):
    try:
        with open(data_file_path) as file:
            json_data = json.load(file)

            if "spotify" in json_data:
                spotify_data = dict(json_data["spotify"])

                if ("client_id" in spotify_data) & ("client_secret" in spotify_data):
                    client_id = spotify_data["client_id"]
                    client_secret = spotify_data["client_id"]

                    url = "https://accounts.spotify.com/api/token"
                    header = create_header(
                        client_id=client_id, client_secret=client_secret)
                    body = {
                        "client_id": client_id,
                        "grant_type": "refresh_token",
                        "refresh_token": refresh_token
                    }
                    request = requests.post(url=url, headers=header, data=body)
                    try:
                        return request.json()
                    except json.decoder.JSONDecodeError:
                        return None
                else:
                    return None
            else:
                return None
    except FileNotFoundError:
        return None
