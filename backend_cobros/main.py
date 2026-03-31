from fastapi import FastAPI

app = FastAPI()

# Aquí simularemos una base de datos pequeña por ahora
clientes_deudores = []

@app.get("/")
def inicio():
    return {"status": "Servidor de Cobros en línea"}

@app.post("/registrar-cliente/")
def registrar(nombre: str, cedula: str, monto: int):
    # Lógica de la cartulina: 5.000 por cada 100.000
    valor_cartulina = (monto // 100000) * 5000
    
    nuevo_cliente = {
        "nombre": nombre,
        "cedula": cedula,
        "prestamo": monto,
        "cartulina": valor_cartulina,
        "saldo_pendiente": monto
    }
    
    clientes_deudores.append(nuevo_cliente)
    return {"mensaje": "Cliente registrado con éxito", "detalle": nuevo_cliente}