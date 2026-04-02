import { Injectable } from '@angular/core';
import { HttpClient, HttpResponse } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface ProductionStatus {
  requestedProduction: string;
  activeProduction: string;
  runningProduction: string;
  isRunning: number;
  stateCode: number;
  stateLabel: string;
  matchesRequestedProduction: number;
  action?: string;
  previousProduction?: string;
}

export interface OrderSummary {
  messageId: number;
  sessionId: number;
  timeCreated: string;
  orderId: string;
  customerId: string;
  orderPriority: string;
  productName: string;
  sales: string;
}

export interface HttpbinEcho {
  args?: Record<string, unknown>;
  data?: string;
  form?: Record<string, unknown>;
  headers?: Record<string, string>;
  json?: Record<string, unknown>;
  origin?: string;
  url?: string;
}

export interface NotificationEcho {
  sessionId: number;
  sourceConfigName: string;
  requestFound: number;
  responseFound: number;
  requestLoggedAt: string;
  responseLoggedAt: string;
  requestRaw: string;
  responseRaw: string;
  requestJson?: Record<string, unknown>;
  responseJson?: HttpbinEcho;
  httpbinOrigin?: string;
  httpbinUrl?: string;
}

export interface LoanPrimeRateResult {
  step: string;
  production: ProductionStatus;
  sourceConfigName: string;
  responseClass: string;
  primeRate: number;
  notes: string[];
}

export interface LoanCreditRatingResult {
  step: string;
  production: ProductionStatus;
  sourceConfigName: string;
  responseClass: string;
  taxId: string;
  creditRating: number;
  derivedRule: string;
  notes: string[];
}

export interface LoanApproval {
  bankName: string;
  isApproved: number;
  interestRate: number | string;
  text: string;
}

export interface LoanBankReply {
  messageId: number;
  sessionId: number;
  timeCreated: string;
  sourceConfigName: string;
  targetConfigName: string;
  bankName: string;
  isApproved: number;
  interestRate: number | string;
}

export interface LoanTraceEntry {
  timeLogged: string;
  configName: string;
  text: string;
}

export interface LoanSessionSummary {
  messageHeaderId: number;
  sessionId: number;
  timeCreated: string;
  messageViewerLink: string;
  visualTraceLink: string;
}

export interface LoanRequestPayload {
  amount: string;
  name: string;
  taxId: string;
  nationality: string;
}

export interface LoanApplicationResult {
  step: string;
  processName: string;
  production: ProductionStatus;
  input: LoanRequestPayload;
  recordNumber: number;
  receiptText: string;
  approval: LoanApproval;
  durationSeconds: number;
  session: LoanSessionSummary;
  bankReplies: LoanBankReply[];
  trace: LoanTraceEntry[];
  notes: string[];
}

@Injectable({
  providedIn: 'root'
})
export class WorkshopService {
  private readonly apiBaseUrl = `${environment.irisUrl}/order/api`;

  constructor(private http: HttpClient) {}

  getProductionStatus(): Observable<HttpResponse<ProductionStatus>> {
    return this.http.get<ProductionStatus>(`${this.apiBaseUrl}/production/status`, {
      observe: 'response'
    });
  }

  startProduction(): Observable<HttpResponse<ProductionStatus>> {
    return this.http.post<ProductionStatus>(`${this.apiBaseUrl}/production/start`, {}, {
      observe: 'response'
    });
  }

  submitInvalidOrder(): Observable<HttpResponse<unknown>> {
    return this.http.post(`${this.apiBaseUrl}/order`, {}, {
      observe: 'response'
    });
  }

  submitValidOrder(order: object): Observable<HttpResponse<unknown>> {
    return this.http.post(`${this.apiBaseUrl}/order`, order, {
      observe: 'response'
    });
  }

  getRecentOrders(): Observable<HttpResponse<OrderSummary[]>> {
    return this.http.get<OrderSummary[]>(`${this.apiBaseUrl}/orders`, {
      observe: 'response'
    });
  }

  getLatestNotificationEcho(sessionId?: number): Observable<HttpResponse<NotificationEcho>> {
    const query = sessionId ? `?sessionId=${sessionId}` : '';

    return this.http.get<NotificationEcho>(`${this.apiBaseUrl}/notifications/latest${query}`, {
      observe: 'response'
    });
  }

  getLoanProductionStatus(): Observable<HttpResponse<ProductionStatus>> {
    return this.http.get<ProductionStatus>(`${this.apiBaseUrl}/loan/production/status`, {
      observe: 'response'
    });
  }

  prepareLoanProduction(): Observable<HttpResponse<ProductionStatus>> {
    return this.http.post<ProductionStatus>(`${this.apiBaseUrl}/loan/production/prepare`, {}, {
      observe: 'response'
    });
  }

  testLoanPrimeRate(): Observable<HttpResponse<LoanPrimeRateResult>> {
    return this.http.post<LoanPrimeRateResult>(`${this.apiBaseUrl}/loan/prime-rate`, {}, {
      observe: 'response'
    });
  }

  testLoanCreditRating(taxId: string): Observable<HttpResponse<LoanCreditRatingResult>> {
    return this.http.post<LoanCreditRatingResult>(`${this.apiBaseUrl}/loan/credit-rating`, { taxId }, {
      observe: 'response'
    });
  }

  submitLoanApplication(payload: LoanRequestPayload): Observable<HttpResponse<LoanApplicationResult>> {
    return this.http.post<LoanApplicationResult>(`${this.apiBaseUrl}/loan/application`, payload, {
      observe: 'response'
    });
  }
}
