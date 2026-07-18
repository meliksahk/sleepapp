import type { Metadata } from 'next';
import { TestView } from '@/components/TestView';
import { buildTestMetadata } from '@/lib/page-metadata';

export const metadata: Metadata = buildTestMetadata('tr');

export default function TrTestPage() {
  return <TestView locale="tr" />;
}
