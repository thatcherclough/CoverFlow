# CoverFlow API

CoverFlow uses a custom python API to generate Apple Music JWT tokens, get Spotify refresh / access tokens, and refresh Spotify refresh / access tokens.
To run the API, replace the sample data in "data.json" and run ``python3 api.py``.

## Open endpoints
Open endpoints require no authentication.

- [Test API](#test-api): ``GET /api``
- [Generate Apple Music JWT token](#generate-apple-music-jwt-token): ``GET /api/apple_music/key``
- [Generate Spotify access and refresh tokens](#generate-spotify-access-and-refresh-tokens): ``POST /api/spotify/swap``
- [Refresh Spotify access and refresh tokens](#refresh-spotify-access-and-refresh-tokens): ``POST /api/spotify/refresh``

## Test API
Used to test if the API is online.

URL: ``/api``

Method: ``GET``

### Success response
Code: ``200``

Content:
```
{
    "message": "CoverFlow API"
}
```

## Generate Apple Music JWT token
Used to generate an Apple Music JWT token.

URL: ``/api/apple_music/key``

Method: ``GET``

### Success response
Code: ``200``

Content example:
```
{
    "key": "eyJ0e...SGDv-BdkeQ"
}
```

### Error response
Code ``400``

Content:
```
{
    "error": "Could not generate key"
}
```

## Generate Spotify access and refresh tokens
Used to generate Spotify access and refresh tokens from an access code and its code verifier.

URL: ``/api/spotify/swap``

Method: ``POST``

### Parameters
```
{
    "access_code": "[spotify access code]",
    "code_verifier": "[corresponding access code verifier]"
}
```

### Success response
Code: ``200``

Content example:
```
{
    "access_token": "NgAagA...Um_SHo",
    "expires_in": "3600"
    "refresh_token": "NgCXwK...MzYjw"
}
```

### Error response
#### Could not get tokens
Code: ``400``

Content:
```
{
    "error": "Could not get access and refresh tokens"
}
```
#### Missing parameters
Code: ``400``

Content:
```
{
    "error": "Missing parameters"
}
```

## Refresh Spotify access and refresh tokens
Used to refresh Spotify access and refresh tokens from a refresh token.

URL: ``/api/spotify/refresh``

Method: ``POST``

### Parameters
```
{
    "refresh_token": "[refresh token]"
}
```

### Success response
Code: ``200``

Content example:
```
{
    "access_token": "NgAagA...Um_SHo",
    "expires_in": "3600"
    "refresh_token": "NgCXwK...MzYjw"
}
```

### Error response
#### Could not refresh tokens
Code: ``400``

Content:
```
{
    "error": "Could not refresh tokens"
}
```
#### Missing parameters
Code: ``400``

Content:
```
{
    "error": "Missing parameters"
}
```