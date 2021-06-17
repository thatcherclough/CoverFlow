import datetime
import jwt
from flask import json

alg = "ES256"
time_now = datetime.datetime.now()
time_expired = datetime.datetime.now() + datetime.timedelta(hours=2)


def generateKey(data_file_path):
    try:
        with open(data_file_path) as file:
            json_data = json.load(file)

            if "apple_music" in json_data:
                apple_music_data = dict(json_data["apple_music"])

                if ("private_key" in apple_music_data) & ("key_id" in apple_music_data) & ("team_id" in apple_music_data):
                    private_key = apple_music_data["private_key"]
                    headers = {
                        "alg": alg,
                        "kid": apple_music_data["key_id"]
                    }
                    payload = {
                        "iss": apple_music_data["team_id"],
                        "exp": int(time_expired.strftime("%s")),
                        "iat": int(time_now.strftime("%s"))
                    }

                    try:
                        key = jwt.encode(payload, private_key,
                                         algorithm=alg, headers=headers)
                        return key
                    except ValueError:
                        return None
                else:
                    return None
            else:
                return None
    except FileNotFoundError:
        return None
