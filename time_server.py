from flask import Flask, escape, request
import time

app = Flask(__name__)

@app.route('/')
@app.route('/index')
def hello():
    return f"{time.time()}"
