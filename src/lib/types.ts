export const categories = ['Protecocho', 'Hidramax', 'Multicocho', 'Nutrisilo', 'Suínos'] as const
export type Category = (typeof categories)[number]
export const units = ['un', 'kg', 'm', 'L'] as const
export type Unit = (typeof units)[number] | ''
export type MovementType = 'entrada' | 'saida' | 'ajuste'

export interface Product {
  id: string
  name: string
  sku: string
  category: Category
  description: string
  unit: Unit
  quantity: number
  minStock: number
  stockKnown?: boolean
  location: string
  active: boolean
  createdAt: string
  updatedAt: string
}

export interface Movement {
  id: string
  productId: string
  type: MovementType
  quantity: number
  previousStock: number
  nextStock: number
  date: string
  user: string
  reason: string
  destination?: string
  reference?: string
  notes?: string
}

export interface ProductForm {
  name: string
  sku: string
  category: Category
  description: string
  unit: Unit
  quantity: string
  minStock: string
  location: string
  active: boolean
}

export interface MovementForm {
  type: MovementType
  productId: string
  quantity: string
  reason: string
  destination: string
  reference: string
  notes: string
}
