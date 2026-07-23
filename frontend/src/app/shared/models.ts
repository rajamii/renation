export interface DigitalVoucher {
  id: string;
  cafe_discount_percentage: number;
  is_cafe_discount_used: boolean;
  free_gaming_minutes: number;
  is_gaming_perk_used: boolean;
  created_at: string;
}

export interface Booking {
  id: number;
  service: any;
  garage_vehicle?: any;
  
  requested_date: string;
  requested_time?: string;
  
  slot?: number;

  status: string;
  payment_window_start?: string;
  estimated_delivery_timeline?: string;
  final_price?: number;
  
  voucher?: DigitalVoucher;
}