export interface DigitalVoucher {
  id: string;
  perk_description: string;
  is_redeemed: boolean;
  redeemed_at?: string;
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