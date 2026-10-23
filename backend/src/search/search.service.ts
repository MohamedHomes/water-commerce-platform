import { Injectable } from '@nestjs/common';
import { CatalogService, GetProductsQueryDto } from '../catalog/catalog.service';

@Injectable()
export class SearchService {
    constructor(private readonly catalogService: CatalogService) { }

    searchProducts(query: GetProductsQueryDto = {}) {
        return this.catalogService.searchProducts(query);
    }
}
