import {
    Body,
    Controller,
    Delete,
    Get,
    Param,
    Patch,
    Post,
    Query,
    UseGuards,
} from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AddressService, CreateAddressDto, UpdateAddressDto } from './address.service';

@Controller('addresses')
@UseGuards(JwtAuthGuard)
export class AddressController {
    constructor(private readonly addressService: AddressService) { }

    @Get()
    getAddresses(@CurrentUser() user: { id: string }) {
        return this.addressService.getAddresses(user.id);
    }

    @Post()
    createAddress(
        @CurrentUser() user: { id: string },
        @Body() dto: CreateAddressDto,
    ) {
        return this.addressService.createAddress(user.id, dto);
    }

    @Patch(':id')
    updateAddress(
        @CurrentUser() user: { id: string },
        @Param('id') id: string,
        @Body() dto: UpdateAddressDto,
    ) {
        return this.addressService.updateAddress(user.id, id, dto);
    }

    @Delete(':id')
    deleteAddress(
        @CurrentUser() user: { id: string },
        @Param('id') id: string,
    ) {
        return this.addressService.deleteAddress(user.id, id);
    }

    @Post(':id/default')
    setDefaultAddress(
        @CurrentUser() user: { id: string },
        @Param('id') id: string,
    ) {
        return this.addressService.setDefaultAddress(user.id, id);
    }

    @Get('cities')
    getCities() {
        return this.addressService.getCities();
    }

    @Get('delivery-zones')
    getDeliveryZones(@Query('city') city?: string) {
        return this.addressService.getDeliveryZones(city);
    }
}
