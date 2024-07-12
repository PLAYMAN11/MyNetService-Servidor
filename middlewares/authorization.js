import { JsonWebTokenError } from "jsonwebtoken";
import dotenv from "dotenv";

function soloUser(req, res, next){
    const cookieJWT = req.headers.cookies.split("; ").find(cookie => cookie.startsWith("jwt=")).slice(4);
    const decodificada = jsonwebtoken.verify(cookieJWT, process.env.jwtSecret);
}
function soloInvitado(req, res, next){
console.log("COOKIE", req.headers.cookies);
}

export const methods = {
    soloUser,
    soloInvitado
}