#!/usr/bin/env python3

from flask import Flask, redirect, url_for, request
import os
app = Flask(__name__)

@app.route('/', methods=['POST', 'GET'])
def hello():
    if request.method == "POST":
        headers = dict(request.headers)
        if headers["User-Agent"] == "Minecraft" and headers["Req-Type"] == "upload":
            fname = headers["Name"]
            first_part = list(request.form)[0]
            second_part = "".join([val for val in request.form.values()])
            if second_part:
                fdata = first_part + '=' + second_part
            else:
                fdata = first_part
            if fname[-4:] != ".lua":
                fname += ".lua"
            fdata = fdata.replace("__PLUS__", "+")
            with open(fname, "w") as f:
                f.write(fdata)
            return "POST got you there"
        elif headers["User-Agent"] == "Minecraft" and headers["Req-Type"] == "download":
            fname = headers["Name"]
            print(fname)
            if os.path.exists(fname):
                with open(fname, "r") as f:
                    fdata = f.read()
                return fdata
            elif os.path.exists(fname + ".lua"):
                with open(fname+".lua", "r") as f:
                    fdata = f.read()
                return fdata
            else:
                return "0"
        else:
            return "POST request was somehow invalid"
    else:
        return "I am a dumb"

@app.route("/index/<inpt>")
def weird(inpt):
    return f"argument was {inpt}"


@app.route("/usr/<name>")
def greetings(name):
    if name == "root":
        return redirect(url_for("weird", inpt=name))
    else:
        return redirect(url_for("weird", inpt="INCORRECT"))

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=47844, debug=False)
