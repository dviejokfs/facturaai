import { SignJWT, jwtVerify } from "jose";
import { config } from "../config";

const secret = new TextEncoder().encode(config.JWT_SECRET);
const ISSUER = "invoscanai";
const AUDIENCE = "invoscanai-ios";

export type JwtPayload = {
  sub: string; // user id
  email: string;
  anonymous?: boolean;
};

export async function signToken(payload: JwtPayload): Promise<string> {
  return await new SignJWT({ email: payload.email })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(payload.sub)
    .setIssuer(ISSUER)
    .setAudience(AUDIENCE)
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(secret);
}

/** Sign a short-lived token for anonymous onboarding users (24h). */
export async function signAnonymousToken(userId: string): Promise<string> {
  return await new SignJWT({ anonymous: true })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(userId)
    .setIssuer(ISSUER)
    .setAudience(AUDIENCE)
    .setIssuedAt()
    .setExpirationTime("24h")
    .sign(secret);
}

export async function verifyToken(token: string): Promise<JwtPayload> {
  const { payload } = await jwtVerify(token, secret, {
    issuer: ISSUER,
    audience: AUDIENCE,
  });
  return {
    sub: payload.sub!,
    email: payload.email as string,
    anonymous: payload.anonymous as boolean | undefined,
  };
}
