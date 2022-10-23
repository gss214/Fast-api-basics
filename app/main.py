from fastapi import FastAPI
from . import models
from .database import engine
from .routers import pokemons, users

app = FastAPI()

models.Base.metadata.create_all(engine)

app.include_router(pokemons.router)
app.include_router(users.router)
