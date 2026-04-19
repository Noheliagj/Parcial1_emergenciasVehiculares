from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi import File, UploadFile
from sqlalchemy.orm import Session
from PIL import Image
import io
import json
import os
import tempfile
import time
from datetime import datetime
import models
import schemas
from database import engine, get_db
import google.generativeai as genai

# Configurar Gemini AI
genai.configure(api_key="AIzaSyBHnYhdMJbV96l7e57vEaofVIQMyeJvoyw")

# El Gerente abre el restaurante
app = FastAPI(title="API de Emergencias Vehiculares")

# CORS - Permisos
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Construimos los estantes (tablas)
models.Base.metadata.create_all(bind=engine)

# --- VENTANILLA DE ATENCIÓN (Endpoints) ---

@app.get("/")
def bienvenida():
    return {"mensaje": "¡El servidor está encendido!"}

# ==========================================
# CU-01: REGISTRAR CLIENTES
# ==========================================
@app.post("/clientes/")
def registrar_cliente(formulario: schemas.ClienteNuevo, db: Session = Depends(get_db)):
    # Verificar si el email ya existe
    existente = db.query(models.Cliente).filter(models.Cliente.email == formulario.email).first()
    if existente:
        raise HTTPException(status_code=400, detail="El correo ya está registrado")

    nuevo_cliente = models.Cliente(
        nombre_completo=formulario.nombre_completo,
        telefono=formulario.telefono,
        email=formulario.email,
        contrasena=formulario.contrasena
    )
    db.add(nuevo_cliente)
    db.commit()
    db.refresh(nuevo_cliente)
    return {"mensaje": "¡Cliente registrado con éxito!", "datos": nuevo_cliente}

# ==========================================
# CU-02: REGISTRAR VEHÍCULOS
# ==========================================
@app.post("/vehiculos/")
def registrar_vehiculo(formulario: schemas.VehiculoNuevo, db: Session = Depends(get_db)):
    # Verificar si la placa ya existe
    existente = db.query(models.Vehiculo).filter(models.Vehiculo.placa == formulario.placa).first()
    if existente:
        raise HTTPException(status_code=400, detail="La placa ya está registrada")

    nuevo_vehiculo = models.Vehiculo(
        placa=formulario.placa,
        marca=formulario.marca,
        modelo=formulario.modelo,
        color=formulario.color,
        cliente_id=formulario.cliente_id
    )
    db.add(nuevo_vehiculo)
    db.commit()
    db.refresh(nuevo_vehiculo)
    return {"mensaje": "¡Vehículo registrado!", "datos": nuevo_vehiculo}

# ==========================================
# CU-03: REGISTRAR TALLERES
# ==========================================
@app.post("/talleres/")
def registrar_taller(formulario: schemas.TallerNuevo, db: Session = Depends(get_db)):
    existente = db.query(models.Taller).filter(models.Taller.email == formulario.email).first()
    if existente:
        raise HTTPException(status_code=400, detail="El correo ya está registrado")

    nuevo_taller = models.Taller(
        nombre_taller=formulario.nombre_taller,
        direccion=formulario.direccion,
        telefono=formulario.telefono,
        email=formulario.email,
        contrasena=formulario.contrasena
    )
    db.add(nuevo_taller)
    db.commit()
    db.refresh(nuevo_taller)
    return {"mensaje": "¡Taller registrado!", "datos": nuevo_taller}

# ==========================================
# CU-04: REGISTRAR TÉCNICOS
# ==========================================
@app.post("/tecnicos/")
def registrar_tecnico(formulario: schemas.TecnicoNuevo, db: Session = Depends(get_db)):
    nuevo_tecnico = models.Tecnico(
        nombre_completo=formulario.nombre_completo,
        especialidad=formulario.especialidad,
        taller_id=formulario.taller_id
    )
    db.add(nuevo_tecnico)
    db.commit()
    db.refresh(nuevo_tecnico)
    return {"mensaje": "¡Técnico registrado!", "datos": nuevo_tecnico}

# ==========================================
# CU-05: REPORTAR EMERGENCIA
# ==========================================
@app.post("/emergencias/")
def reportar_emergencia(formulario: schemas.EmergenciaNueva, db: Session = Depends(get_db)):
    # Verificar que el vehículo existe
    vehiculo = db.query(models.Vehiculo).filter(models.Vehiculo.id == formulario.vehiculo_id).first()
    if not vehiculo:
        raise HTTPException(status_code=404, detail="Vehículo no encontrado")

    nueva_emergencia = models.Emergencia(
        cliente_id=formulario.cliente_id,
        vehiculo_id=formulario.vehiculo_id,
        direccion=formulario.direccion,
        descripcion=formulario.descripcion,
        audio_url=formulario.audio_url,
        estado="Pendiente"
    )
    db.add(nueva_emergencia)
    db.commit()
    db.refresh(nueva_emergencia)

    return {"mensaje": "¡Emergencia reportada! Buscando taller cercano...", "datos": nueva_emergencia}

# ==========================================
# LOGIN TALLER
# ==========================================
@app.post("/login-taller/")
def iniciar_sesion_taller(credenciales: schemas.LoginTaller, db: Session = Depends(get_db)):
    taller_encontrado = db.query(models.Taller).filter(models.Taller.email == credenciales.email).first()
    if taller_encontrado is None or taller_encontrado.contrasena != credenciales.contrasena:
        raise HTTPException(status_code=401, detail="Correo o contraseña incorrectos")
    return {"mensaje": "¡Bienvenido al sistema!", "datos": taller_encontrado}

# ==========================================
# LOGIN CLIENTE
# ==========================================
@app.post("/login-cliente/")
def login_cliente(credenciales: schemas.LoginCliente, db: Session = Depends(get_db)):
    user = db.query(models.Cliente).filter(models.Cliente.email == credenciales.email).first()
    if not user or user.contrasena != credenciales.contrasena:
        raise HTTPException(status_code=401, detail="Correo o contraseña incorrectos")
    return {"mensaje": "Bienvenido", "usuario": user.nombre_completo, "usuario_id": user.id}

# ==========================================
# OBTENER VEHÍCULOS POR CLIENTE
# ==========================================
@app.get("/vehiculos/cliente/{cliente_id}")
def obtener_vehiculos_de_cliente(cliente_id: int, db: Session = Depends(get_db)):
    vehiculos = db.query(models.Vehiculo).filter(models.Vehiculo.cliente_id == cliente_id).all()
    return vehiculos

# ==========================================
# OBTENER EMERGENCIAS PENDIENTES PARA TALLER
# ==========================================
@app.get("/emergencias-taller/")
def ver_emergencias_para_taller(db: Session = Depends(get_db)):
    return db.query(models.Emergencia).filter(models.Emergencia.estado == "Pendiente").all()

# ==========================================
# CU-06: CONSULTAR ESTADO DE SOLICITUD
# ==========================================
@app.get("/api/emergencias/{emergencia_id}/estado")
def consultar_estado_emergencia(emergencia_id: int, db: Session = Depends(get_db)):
    """Permite al cliente consultar el estado actual de su solicitud"""
    emergencia = db.query(models.Emergencia).filter(models.Emergencia.id == emergencia_id).first()
    if not emergencia:
        raise HTTPException(status_code=404, detail="Emergencia no encontrada")

    # Obtener historial de estados
    historial = db.query(models.HistorialEstado).filter(
        models.HistorialEstado.emergencia_id == emergencia_id
    ).order_by(models.HistorialEstado.fecha_cambio.desc()).all()

    # Obtener datos del taller y técnico si existen
    nombre_taller = None
    nombre_tecnico = None
    if emergencia.taller_id:
        taller = db.query(models.Taller).filter(models.Taller.id == emergencia.taller_id).first()
        if taller:
            nombre_taller = taller.nombre_taller
    if emergencia.tecnico_id:
        tecnico = db.query(models.Tecnico).filter(models.Tecnico.id == emergencia.tecnico_id).first()
        if tecnico:
            nombre_tecnico = tecnico.nombre_completo

    return {
        "emergencia": emergencia,
        "historial_estados": historial,
        "nombre_taller": nombre_taller,
        "nombre_tecnico": nombre_tecnico
    }

# ==========================================
# CU-06: OBTENER EMERGENCIAS POR CLIENTE
# ==========================================
@app.get("/api/clientes/{cliente_id}/emergencias")
def obtener_emergencias_de_cliente(cliente_id: int, db: Session = Depends(get_db)):
    """Obtiene todas las emergencias de un cliente con su estado actual"""
    emergencias = db.query(models.Emergencia).filter(
        models.Emergencia.cliente_id == cliente_id
    ).order_by(models.Emergencia.fecha_creacion.desc()).all()

    resultado = []
    for em in emergencias:
        taller_nombre = None
        tecnico_nombre = None
        if em.taller_id:
            taller = db.query(models.Taller).filter(models.Taller.id == em.taller_id).first()
            if taller:
                taller_nombre = taller.nombre_taller
        if em.tecnico_id:
            tecnico = db.query(models.Tecnico).filter(models.Tecnico.id == em.tecnico_id).first()
            if tecnico:
                tecnico_nombre = tecnico.nombre_completo

        resultado.append({
            "id": em.id,
            "direccion": em.direccion,
            "descripcion": em.descripcion,
            "estado": em.estado,
            "fecha_creacion": em.fecha_creacion,
            "taller_asignado": taller_nombre,
            "tecnico_asignado": tecnico_nombre,
            "transcripcion": em.transcripcion
        })

    return resultado

# ==========================================
# CU-08: ACEPTAR SOLICITUD
# ==========================================
@app.put("/api/emergencias/{emergencia_id}/aceptar")
def aceptar_solicitud(emergencia_id: int, db: Session = Depends(get_db),
                      taller_id: int = None, tecnico_id: int = None):
    """Permite al taller aceptar una solicitud de emergencia"""
    emergencia = db.query(models.Emergencia).filter(models.Emergencia.id == emergencia_id).first()
    if not emergencia:
        raise HTTPException(status_code=404, detail="Emergencia no encontrada")

    if emergencia.estado not in ["Pendiente", "Asignada"]:
        raise HTTPException(status_code=400, detail=f"No se puede aceptar. Estado actual: {emergencia.estado}")

    # Guardar estado anterior
    estado_anterior = emergencia.estado

    # Actualizar emergencia
    emergencia.estado = "Aceptada"
    if taller_id:
        emergencia.taller_id = taller_id
    if tecnico_id:
        emergencia.tecnico_id = tecnico_id
    emergencia.fecha_actualizacion = datetime.now()

    # Registrar en historial
    historial = models.HistorialEstado(
        emergencia_id=emergencia_id,
        estado_anterior=estado_anterior,
        estado_nuevo="Aceptada",
        descripcion="El taller aceptó la solicitud"
    )
    db.add(historial)
    db.commit()

    return {"mensaje": "Solicitud aceptada exitosamente", "datos": emergencia}

# ==========================================
# CU-08: RECHAZAR SOLICITUD
# ==========================================
@app.put("/api/emergencias/{emergencia_id}/rechazar")
def rechazar_solicitud(emergencia_id: int, db: Session = Depends(get_db),
                       motivo: str = None):
    """Permite al taller rechazar una solicitud de emergencia"""
    emergencia = db.query(models.Emergencia).filter(models.Emergencia.id == emergencia_id).first()
    if not emergencia:
        raise HTTPException(status_code=404, detail="Emergencia no encontrada")

    if emergencia.estado not in ["Pendiente", "Asignada"]:
        raise HTTPException(status_code=400, detail=f"No se puede rechazar. Estado actual: {emergencia.estado}")

    # Guardar estado anterior
    estado_anterior = emergencia.estado

    # Actualizar emergencia - vuelve a Pendiente para reasignar
    emergencia.estado = "Pendiente"
    emergencia.observaciones = f"Rechazada: {motivo}" if motivo else "Rechazada"
    emergencia.fecha_actualizacion = datetime.now()

    # Registrar en historial
    historial = models.HistorialEstado(
        emergencia_id=emergencia_id,
        estado_anterior=estado_anterior,
        estado_nuevo="Rechazada",
        descripcion=motivo or "Taller rechazó la solicitud"
    )
    db.add(historial)
    db.commit()

    return {"mensaje": "Solicitud rechazada. Reasignando...", "datos": emergencia}

# ==========================================
# CU-09: ACTUALIZAR ESTADO DEL SERVICIO
# ==========================================
@app.put("/api/emergencias/{emergencia_id}/estado")
def actualizar_estado_servicio(emergencia_id: int, request: schemas.ActualizarEstadoRequest,
                                db: Session = Depends(get_db)):
    """Permite al técnico actualizar el estado del servicio en tiempo real"""
    emergencia = db.query(models.Emergencia).filter(models.Emergencia.id == emergencia_id).first()
    if not emergencia:
        raise HTTPException(status_code=404, detail="Emergencia no encontrada")

    # Validar estados permitidos
    estados_validos = ["En Camino", "En Proceso", "Finalizado", "Cancelado"]
    if request.estado not in estados_validos:
        raise HTTPException(status_code=400, detail=f"Estado inválido. Válidos: {estados_validos}")

    # Guardar estado anterior
    estado_anterior = emergencia.estado

    # Actualizar emergencia
    emergencia.estado = request.estado
    if request.observaciones:
        emergencia.observaciones = request.observaciones
    if request.tecnico_id:
        emergencia.tecnico_id = request.tecnico_id
    emergencia.fecha_actualizacion = datetime.now()

    # Registrar en historial
    historial = models.HistorialEstado(
        emergencia_id=emergencia_id,
        estado_anterior=estado_anterior,
        estado_nuevo=request.estado,
        descripcion=request.observaciones or f"Estado actualizado a {request.estado}"
    )
    db.add(historial)
    db.commit()
    db.refresh(emergencia)

    return {"mensaje": f"Estado actualizado a {request.estado}", "datos": emergencia}

# ==========================================
# CU-10: TRANSCRIBIR AUDIO DEL INCIDENTE
# ==========================================
@app.post("/api/emergencias/transcribir-audio")
async def transcribir_audio(emergencia_id: int, audio: UploadFile = File(...),
                            db: Session = Depends(get_db)):
    """Transcribe audio del incidente usando IA de Google"""
    emergencia = db.query(models.Emergencia).filter(models.Emergencia.id == emergencia_id).first()
    if not emergencia:
        raise HTTPException(status_code=404, detail="Emergencia no encontrada")

    try:
        # Leer el audio
        audio_bytes = await audio.read()

        # Usar Gemini para transcribir
        model = genai.GenerativeModel('gemini-2.5-flash')

        prompt = """
        Transcribe el siguiente audio de un incidente vehicular.
        Identifica: tipo de problema, síntomas descritos, nivel de urgencia.
        Devuelve SOLO la transcripción textual limpia, sin comentarios adicionales.
        """

        # Crear archivo temporal para Gemini
        import tempfile
        with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as f:
            f.write(audio_bytes)
            temp_path = f.name

        # Subir archivo a Gemini
        audio_file = genai.upload_file(path=temp_path)

        # Esperar procesamiento
        import time
        while audio_file.state.name == "PROCESSING":
            time.sleep(2)
            audio_file = genai.get_file(audio_file.name)

        if audio_file.state.name == "FAILED":
            raise HTTPException(status_code=500, detail="Error procesando audio con IA")

        # Generar transcripción
        response = model.generate_content([prompt, audio_file])
        transcripcion = response.text.strip()

        # Guardar en la emergencia
        emergencia.transcripcion = transcripcion
        emergencia.fecha_actualizacion = datetime.now()
        db.commit()

        # Limpiar archivo temporal
        import os
        os.unlink(temp_path)

        return {
            "emergencia_id": emergencia_id,
            "transcripcion": transcripcion,
            "exito": True
        }

    except Exception as e:
        print(f"ERROR en transcripción: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error transcribiendo audio: {str(e)}")

# ==========================================
# OBTENER HISTORIAL DE ESTADOS
# ==========================================
@app.get("/api/emergencias/{emergencia_id}/historial")
def obtener_historial_estados(emergencia_id: int, db: Session = Depends(get_db)):
    """Obtiene el historial completo de cambios de estado de una emergencia"""
    historial = db.query(models.HistorialEstado).filter(
        models.HistorialEstado.emergencia_id == emergencia_id
    ).order_by(models.HistorialEstado.fecha_cambio.desc()).all()

    return historial

# ==========================================
# CU-11: CLASIFICAR IMAGEN DEL INCIDENTE
# ==========================================
@app.post("/api/emergencias/clasificar-imagen")
async def clasificar_incidente(imagen: UploadFile = File(...)):
    """Clasifica el tipo de incidente usando IA de Gemini"""
    try:
        print(f"--- Recibiendo imagen: {imagen.filename} ---")
        image_bytes = await imagen.read()
        img = Image.open(io.BytesIO(image_bytes))

        model = genai.GenerativeModel('gemini-2.5-flash')

        prompt = """
        Eres un perito experto en incidentes vehiculares.
        Analiza la imagen y responde con un JSON válido:
        {
            "tipo_incidente": "batería" | "llanta" | "choque" | "motor" | "otros",
            "nivel_severidad": "Leve" | "Moderado" | "Grave" | "Crítico",
            "sugiere_grua": true | false,
            "confianza_ia": "95%"
        }

        REGLAS:
        1. Llanta/batería → Leve/Moderado, sugiere_grua: false
        2. Choque con daño estructural → sugiere_grua: true
        3. Motor con humo/fuego → sugiere_grua: true
        """

        response = model.generate_content([prompt, img])
        raw_text = response.text.strip()
        cleaned_text = raw_text.replace("```json", "").replace("```", "").strip()
        datos_ia = json.loads(cleaned_text)

        return {"analisis_ia": datos_ia}

    except Exception as e:
        print(f"ERROR CRÍTICO: {str(e)}")
        return {"error": str(e)}

# ==========================================
# OBTENER EMERGENCIAS POR TALLER
# ==========================================
@app.get("/api/talleres/{taller_id}/emergencias")
def obtener_emergencias_por_taller(taller_id: int, estado: str = None,
                                    db: Session = Depends(get_db)):
    """Obtiene todas las emergencias asignadas a un taller"""
    query = db.query(models.Emergencia).filter(models.Emergencia.taller_id == taller_id)

    if estado:
        query = query.filter(models.Emergencia.estado == estado)

    emergencias = query.order_by(models.Emergencia.fecha_creacion.desc()).all()
    return emergencias
