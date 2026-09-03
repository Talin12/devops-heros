from flask import Flask

app = Flask(__name__)


@app.route("/")
def hello():
    return """<!doctype html>
<html>
  <head><title>Python Hello World</title></head>
  <body style="font-family:sans-serif;text-align:center;padding-top:80px">
    <h1>Hello World from Python + Flask </h1>
    <p>Served from inside a Docker container</p>
    <p>Talin Daga | 24BCS10321</p>
  </body>
</html>"""


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
