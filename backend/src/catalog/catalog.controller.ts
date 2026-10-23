import { Controller, Get, Param, Query } from '@nestjs/common';
import { CatalogService, GetProductsQueryDto } from './catalog.service';

@Controller('catalog')
export class CatalogController {
    constructor(private readonly catalogService: CatalogService) { }

    @Get('categories')
    getCategories() {
        return this.catalogService.getCategories();
    }

    @Get('brands')
    getBrands() {
        return this.catalogService.getBrands();
    }

    @Get('products')
    getProducts(@Query() query: GetProductsQueryDto) {
        return this.catalogService.getProducts(query);
    }

    @Get('products/:id')
    getProductById(@Param('id') id: string) {
        return this.catalogService.getProductById(id);
    }
}
