import type { Metadata } from 'next';
import { HomeView } from '@/components/HomeView';
import { buildHomeMetadata } from '@/lib/page-metadata';

export const metadata: Metadata = buildHomeMetadata('tr');

export default function TrHomePage() {
  return <HomeView locale="tr" />;
}
