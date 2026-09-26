from fastapi import FastAPI

app = FastAPI(
    title="Ika Travel API",
    description="Backend para la aplicación de turismo en Ica",
    version="1.0.0"
)

@app.get("/")
async def root():
    return {"message": "Bienvenido a la API de Ika Travel"}
