/** Admin kullanıcı arama sonucu — API `GET /v1/admin/users` yanıtının panel görünümü.
 * Yalnızca kimlik/tür/e-posta/oluşturma; parola/token/2FA API'de zaten dönmez. */
export interface AdminUser {
  id: string;
  kind: string;
  email: string | null;
  createdAt: string;
}
