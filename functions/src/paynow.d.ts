// Minimal type declarations for the official "paynow" npm package (it ships no .d.ts).
declare module "paynow" {
  export class Payment {
    reference: string;
    authEmail: string;
    add(title: string, amount: number, quantity?: number): Payment;
  }
  export interface InitResponse {
    success: boolean;
    hasRedirect: boolean;
    redirectUrl?: string;
    error?: string;
    pollUrl?: string;
    instructions?: string;
    status: string;
  }
  export interface StatusResponse {
    reference?: string;
    amount?: string;
    paynowReference?: string;
    pollUrl?: string;
    status?: string;
    error?: string;
  }
  export class Paynow {
    constructor(integrationId: string, integrationKey: string, resultUrl: string, returnUrl: string);
    resultUrl: string;
    returnUrl: string;
    createPayment(reference: string, authEmail: string): Payment;
    send(payment: Payment): Promise<InitResponse | undefined>;
    sendMobile(payment: Payment, phone: string, method: string): Promise<InitResponse | undefined>;
    pollTransaction(url: string): Promise<InitResponse | undefined>;
    parseStatusUpdate(body: string): StatusResponse;
  }
}
