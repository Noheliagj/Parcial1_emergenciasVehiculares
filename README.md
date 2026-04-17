
 Sistema de Emergencias Vehiculares (Parcial 1 - SI2)

¡Bienvenido/a al proyecto! Este repositorio contiene el código completo del sistema, dividido en tres partes principales:
1. **Backend:** Creado con Python y FastAPI.
2. **Frontend Web:** Creado con Angular.
3. **App Móvil Cliente:** Creada con Flutter.

Sigue estos pasos EXACTOS para que el proyecto corra en tu computadora sin errores.

##  1. Requisitos Previos (Lo que debes tener instalado)
Antes de empezar, asegúrate de tener instalados estos programas en tu computadora:
* [Git](https://git-scm.com/)
* [Python](https://www.python.org/downloads/) (Recomendado 3.10+)
* [Node.js](https://nodejs.org/) (Para correr Angular)
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (Para correr la app móvil)


##  2. Descargar el Proyecto (Clonar)
Abre tu terminal (o consola) en la carpeta donde quieras guardar el proyecto y ejecuta:


git clone https://github.com/Noheliagj/Parcial1_emergenciasVehiculares.git
cd Parcial1_emergenciasVehiculares


##  3. Levantar el Servidor Backend (FastAPI)
Abre una nueva terminal dentro de la carpeta del proyecto y ejecuta estos comandos:

1. Entra a la carpeta del backend:

   cd backend

2. Crea y activa el entorno virtual:
   
   * **Windows:**
     python -m venv venv
     luego
     .\venv\Scripts\activate
   * **Mac/Linux:**
     python -m venv venv
     luego
     source venv/bin/activate
     
4. Instala las librerías:

   pip install -r requirements.txt

5. Enciende el servidor:
   
   uvicorn main:app --reload


##  4. Levantar la Web (Angular)
Abre otra terminal nueva en la raíz del proyecto y ejecuta:

1. Entra a la carpeta de la web:
   
   cd frontend-web
   
2. Instala los paquetes e inicia:
   
   npm install
   ng serve -o
   

##  5. Levantar la App Móvil (Flutter)
Abre otra terminal nueva en la raíz del proyecto y ejecuta:

1. Entra a la carpeta de la aplicación:
   
   cd app_cliente
   
2. Prepara y corre la app:
   
   flutter pub get
   flutter run
   
