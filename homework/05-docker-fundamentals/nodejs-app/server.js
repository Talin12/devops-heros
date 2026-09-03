const express = require("express");
const app = express();
const PORT = process.env.PORT || 3000;

app.get("/", (req, res) => {
  res.send(`<!doctype html>
<html>
  <head><title>Node.js Hello World</title></head>
  <body style="font-family:sans-serif;text-align:center;padding-top:80px">
    <h1>Hello World from Node.js + Express </h1>
    <p>Served from inside a Docker container</p>
    <p>Talin Daga | 24BCS10321</p>
  </body>
</html>`);
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Node.js app listening on port ${PORT}`);
});
