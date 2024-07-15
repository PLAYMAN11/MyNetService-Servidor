const express = require("express");
const Router = express.Router();
const { createConnection } = require("../db.js");
const jwt = require("jsonwebtoken");
const dotenv = require("dotenv");
const { status } = require("init");
const { send } = require("process");
const { Domain } = require("domain");

const RUN = createConnection();
dotenv.config();

Router.get("/TablaUsuarios", (req, res) => {
RUN.query("SELECT * FROM usuarios", (err, result) => {
    if (err) {
       res.status(500).send("No se pudo obtener la tabla de usuarios");
    } else {
       res.status(200).send(result);
       }
});
});

Router.post("/Registro", (req, res) => {
    const { NombreUsuario, Contraseña, ApellidoUsuario, CorreoUsuario, Telefono, FECHA_NACIMIENTO } = req.body;
    RUN.query(`INSERT INTO usuarios (NombreUsuario, Contraseña, ApellidoUsuario, CorreoUsuario, Telefono, Estado, FECHA_NACIMIENTO)
VALUES (?, ?, ?, ?, ?, "Activo", ?)`, [NombreUsuario, Contraseña, ApellidoUsuario, CorreoUsuario, Telefono, FECHA_NACIMIENTO], (err, result) => {
        if (err) {
            res.status(500).send("Error al registrar usuario");
        } else {
            res.status(200).send("Usuario registrado exitosamente");
        }
    });
});


Router.post("/IniciarSesion", (req, res) => {
    const { CorreoUsuario, Contraseña } = req.body;
    console.log("Iniciando sesión para:", CorreoUsuario); // Log de depuración

    RUN.query('SELECT idusuario FROM usuarios WHERE CorreoUsuario = ? AND Contraseña = ?', [CorreoUsuario, Contraseña], (err, result) => {
        if (err) {
            console.error("Error en la consulta:", err); // Log de error
            res.status(500).send("Sesion no encontrada");
        } else {
            console.log("Resultado de la consulta:", result); // Log del resultado
            if (result.length > 0) {
                const idUsuario = result[0].idusuario;

                try {
                    const token= jwt.sign(
                        { idUsuario },
                        process.env.jwtSecret,
                        { expiresIn: process.env.jwtExpiresIn }
                    );
                    const cookieOptions = {
                        expires: (process.env.CookieExpiration * 24 * 60 * 60 * 1000),
                        path: '/',
                        secure: false,
                        httpOnly: true
                    };
                    res.status(200).json({
                        token: token,
                        expires: cookieOptions.expires,
                        path: cookieOptions.path,
                        secure: cookieOptions.secure,
                        httpOnly: cookieOptions.httpOnly,
                      });
                } catch (error) {
                    console.error("Error al generar el token:", error); // Log de error al generar el token
                    res.status(500).send("Error al iniciar sesión");
                }
            } else {
                res.status(401).send("Correo o contraseña incorrectos");
            }
        }
    });
});

module.exports = Router;
