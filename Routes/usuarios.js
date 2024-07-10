const express = require("express");
const Router = express.Router();
const { createConnection } = require("../db.js");
const jwt = require("jsonwebtoken");
const dotenv = require("dotenv").config();
const { status } = require("init");

const RUN = createConnection();


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

Router.post("/IniciarSesion", (req, res) =>{
    const {CorreoUsuario, Contraseña} = req.body;
    RUN.query('SELECT idUsuario From usuarios where CorreoUsuario = ? && Contraseña = ?', [CorreoUsuario, Contraseña], (err, result) =>{
        if(err){
            res.status(500).send("Sesion no encontrada");
        } else {
            if(result.length > 0){
                const idUsuario = result[0].idUsuario;
                const token = jwt.sign(
                    {idUsuario}, 
                    process.env.jwtSecret, 
                    {expiresIn:process.env.jwtExpiresIn});
                const cookieOptions = {
                    expires: new Date (Date.now() + process.env.CookieExpiration * 24 * 60 * 60 * 1000),
                    path: '/',
                }
                res.cookie("jwt",token,cookieOptions);
                res.send({status:'ok', message:'logged in'})
            } else {
                res.status(401).send("Correo o contraseña incorrectos");
            }
        }
    })

})

module.exports = Router;
