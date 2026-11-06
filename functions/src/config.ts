// Business rules (SRS section 8.3). Change these values, then redeploy functions.
export const CONFIG = {
  appName: "SkillBridge",
  currency: "USD",
  /** Platform commission taken from each released payment (FR-6.5). */
  commissionRate: 0.1,
  /** Hours after the provider marks a job complete before escrow auto-releases (FR-6.4). */
  autoReleaseHours: 48,
  /** Hours a provider has to answer a request before it expires (FR-5.4). */
  requestExpiryHours: 24,
  /** Hours a client has to pay an accepted quote before it is cancelled. */
  paymentExpiryHours: 24,
  /** Client cancelling less than this many hours before the job pays a late fee. */
  freeCancelHours: 24,
  /** Share of the fee paid to the provider on a late client cancellation. */
  lateCancelFeeRate: 0.2,
  /** Minimum wallet withdrawal, in cents. */
  minWithdrawalCents: 500,
};

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
