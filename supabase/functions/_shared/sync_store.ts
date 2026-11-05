// SyncStore on Postgres (service role). Each call is one RPC from
// supabase/migrations/20261105000002_sync_log_devices.sql.

import type { SupabaseClient } from "npm:@supabase/supabase-js@2.49.4";
import { getServiceClient } from "./supabase.ts";
import {
  type AppendArgs,
  base64Field,
  byteaParam,
  type ChallengeKeys,
  type ChallengePurpose,
  dbErrorToHttp,
  type Session,
  type SyncStore,
} from "./sync.ts";

export class SupabaseSyncStore implements SyncStore {
  constructor(private readonly db: SupabaseClient = getServiceClient()) {}

  private async call(fn: string, args: Record<string, unknown>): Promise<unknown> {
    const { data, error } = await this.db.rpc(fn, args);
    if (error) throw dbErrorToHttp(error, fn);
    return data;
  }

  async takeChallenge(
    session: Session,
    purpose: ChallengePurpose,
    deviceId: string,
    nonce: Uint8Array,
  ): Promise<ChallengeKeys> {
    const data = await this.call("take_device_challenge", {
      p_user: session.userId,
      p_session: session.sessionId,
      p_purpose: purpose,
      p_device: deviceId,
      p_nonce: byteaParam(nonce),
    }) as { device: Record<string, unknown>; signer: Record<string, unknown> };
    return {
      device: {
        id: String(data.device.id),
        kx: base64Field(data.device.kx, "device.kx"),
        sig: base64Field(data.device.sig, "device.sig"),
      },
      signer: { id: String(data.signer.id), sig: base64Field(data.signer.sig, "signer.sig") },
    };
  }

  async bindDevice(session: Session, deviceId: string, enroll: boolean) {
    return await this.call("bind_device_signed", {
      p_user: session.userId,
      p_session: session.sessionId,
      p_device: deviceId,
      p_enroll: enroll,
    }) as Record<string, unknown>;
  }

  async approveDevice(
    session: Session,
    deviceId: string,
    pairingId: string | null,
    bundle: Uint8Array | null,
    signerId: string,
  ) {
    return await this.call("approve_device_signed", {
      p_user: session.userId,
      p_session: session.sessionId,
      p_device: deviceId,
      p_pairing: pairingId,
      p_bundle: byteaParam(bundle),
      p_signer: signerId,
    }) as Record<string, unknown>;
  }

  async recoverDevice(session: Session, deviceId: string, signerId: string) {
    return await this.call("recover_device_signed", {
      p_user: session.userId,
      p_session: session.sessionId,
      p_device: deviceId,
      p_signer: signerId,
    }) as Record<string, unknown>;
  }

  async deviceSigningKey(deviceId: string): Promise<Uint8Array | null> {
    const data = await this.call("device_signing_key", { p_device: deviceId });
    return typeof data === "string" ? base64Field(data, "signing key") : null;
  }

  async appendFamilyLog(args: AppendArgs) {
    return await this.call("append_family_log_as", {
      p_user: args.session.userId,
      p_session: args.session.sessionId,
      p_family: args.familyId,
      p_seq: args.seq,
      p_prev_hash: byteaParam(args.prevHash),
      p_entry: byteaParam(args.entry),
      p_sig: byteaParam(args.sig),
      p_history: byteaParam(args.history),
      p_wraps: args.wraps,
    }) as Record<string, unknown>;
  }

  async sessionDevice(session: Session) {
    const data = await this.call("session_device_key", {
      p_user: session.userId,
      p_session: session.sessionId,
    }) as { device_id: string; sig: string } | null;
    return data ? { deviceId: data.device_id, sig: base64Field(data.sig, "signing key") } : null;
  }

  async publishHead(session: Session, familyId: string, beacon: Uint8Array, sig: Uint8Array) {
    return await this.call("publish_family_head", {
      p_user: session.userId,
      p_session: session.sessionId,
      p_family: familyId,
      p_beacon: byteaParam(beacon),
      p_sig: byteaParam(sig),
    }) as Record<string, unknown>;
  }
}

/** Verifies the token with Auth and returns its user id (null if invalid). */
export async function verifyUserToken(token: string): Promise<string | null> {
  const { data, error } = await getServiceClient().auth.getUser(token);
  return error || !data.user ? null : data.user.id;
}
