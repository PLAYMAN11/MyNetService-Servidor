const express = require("express");
const Router = express.Router();
const { createConnection } = require("../db.js");

const RUN = createConnection();

Router.get("/", (req, res) => {
    RUN.query("SELECT * FROM usuarios", (err, rows) => {
        if (err) {
            res.status(500).send("Error obteniendo usuarios");
        } else {
            res.json(rows);
        }
    });
});


Router.get("/:id", (req, res) => {
   RUN.query(`SELECT * FROM usuarios WHERE idusuario = ?`, [req.params.id], (err, rows) => {
        if (err) {
            res.status(500).send("Error obteniendo usuario");
        }else{
            res.json(rows);
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

module.exports = Router;