// Business rules (SRS section 8.3). Change these values, then redeploy functions.
export const CONFIG = {
  appName: "SkillBridge",
  currency: "USD",
  /** Share of each job charged to the provider's prepaid balance when the job closes. Also set in the app's AppConfig. */
  commissionRate: 0.1,
  /** Hours after the provider marks a job complete before it closes automatically (FR-6.4). */
  autoReleaseHours: 48,
  /** Hours a provider has to answer a request before it expires (FR-5.4). */
  requestExpiryHours: 24,
  /** Hours a client has to accept a quote before it is cancelled. */
  paymentExpiryHours: 24,
  /** Escrow bookings only: a client cancelling less than this many hours before the job pays a late fee. */
  freeCancelHours: 24,
  /** Escrow bookings only: share of the fee paid to the provider on a late client cancellation. */
  lateCancelFeeRate: 0.2,
  /** Minimum wallet withdrawal, in cents. */
  minWithdrawalCents: 500,
  /** Minimum provider balance top-up, in cents. Also set in the app's AppConfig. */
  minTopUpCents: 100,
};

/** The charge on a job of this value, in cents. */
export function commissionOn(feeCents: number): number {
  return Math.round(feeCents * CONFIG.commissionRate);
}

export const BOOKING_STATUS = {
  pending: "pending",
  awaitingPayment: "awaiting_payment",
  confirmed: "confirmed",
  inTransit: "in_transit",
  inProgress: "in_progress",
  completed: "completed",
  closed: "closed",
  cancelled: "cancelled",
  declined: "declined",
  expired: "expired",
  disputed: "disputed",
} as const;
