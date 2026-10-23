import { Controller, Get, Query } from '@nestjs/common';
import { GetProductsQueryDto } from '../catalog/catalog.service';
import { SearchService } from './search.service';

@Controller('search')
export class SearchController {
    constructor(private readonly searchService: SearchService) { }

    @Get('products')
    searchProducts(@Query() query: GetProductsQueryDto) {
        return this.searchService.searchProducts(query);
    }
}
