import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'NOCTA Admin',
  description: 'NOCTA yönetim paneli',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
