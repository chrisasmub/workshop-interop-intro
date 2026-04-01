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
}
