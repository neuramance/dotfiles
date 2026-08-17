#!/bin/sh
exec security find-generic-password -a "$USER" -s tfy-auth-token -w
