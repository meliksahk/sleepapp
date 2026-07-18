import type { Metadata } from 'next';
import { FaqView } from '@/components/FaqView';
import { buildFaqMetadata } from '@/lib/page-metadata';

export const metadata: Metadata = buildFaqMetadata('tr');

export default function TrFaqPage() {
  return <FaqView locale="tr" />;
}
