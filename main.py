from fastapi import FastAPI
from datetime import datetime
import pytz

app = FastAPI()

@app.get("/current-time")
async def get_current_time():
    # Get the current time in UTC
    utc_now = datetime.now(pytz.utc)
    return {"current_time": utc_now.isoformat()}