const express = require("express");
const Router = express.Router();
const jwt = require('jsonwebtoken');

const validateCookie = (cookie) => {
    if (typeof cookie !== 'string') {
        console.error("Cookie is not a string");
        return false;
    }

    try {
        const token = cookie.split('=')[1];
        const decoded = jwt.verify(token, process.env.jwtSecret);
        return !!decoded; 
    } catch (error) {
        if (error instanceof jwt.JsonWebTokenError) {
            console.error("Invalid cookie:", error.message);
        } else if (error instanceof jwt.TokenExpiredError) {
            console.error("Expired cookie:", error.message);
        } else {
            console.error("Error validating cookie:", error.message);
        }
        return false;
    }
};

module.exports = { validateCookie };


