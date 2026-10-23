import { AddressService, CreateAddressDto } from '../src/address/address.service';
import { AuthService } from '../src/auth/auth.service';
import { createTestApplication } from './database-test-utils';

describe('AddressService persistence', () => {
    let addressService: AddressService;
    let customerId: string;
    let otherCustomerId: string;
    let close: () => Promise<void>;

    beforeEach(async () => {
        const setup = await createTestApplication();
        close = setup.close;
        addressService = setup.app.get(AddressService);
        const registration = await setup.app.get(AuthService).register({
            email: `address-${Date.now()}@example.com`,
            password: 'StrongPass123!',
            firstName: 'Address',
            lastName: 'Customer',
        });
        customerId = registration.customer.id;
        const otherRegistration = await setup.app.get(AuthService).register({
            email: `other-address-${Date.now()}@example.com`,
            password: 'StrongPass123!',
            firstName: 'Other',
            lastName: 'Customer',
        });
        otherCustomerId = otherRegistration.customer.id;
    });

    afterEach(async () => {
        await close();
    });

    function address(overrides: Partial<CreateAddressDto> = {}): CreateAddressDto {
        return {
            label: 'Home',
            recipientName: 'Customer One',
            phone: '+966500000111',
            city: 'Riyadh',
            district: 'Central',
            street: 'Main Street',
            building: '12',
            ...overrides,
        };
    }

    it('returns persisted cities and filters delivery zones by city', async () => {
        expect((await addressService.getCities()).items.map((city) => city.name)).toEqual(['Riyadh', 'Jeddah']);
        expect((await addressService.getDeliveryZones('Jeddah')).items.map((zone) => zone.id))
            .toEqual(['zone-jeddah-central']);
    });

    it('enforces customer ownership across address operations', async () => {
        const created = await addressService.createAddress(customerId, address());

        await expect(addressService.getAddressById(otherCustomerId, created.id))
            .rejects.toThrow('Address not found');
        await expect(addressService.updateAddress(otherCustomerId, created.id, { notes: 'No access' }))
            .rejects.toThrow('Address not found');
        await expect(addressService.deleteAddress(otherCustomerId, created.id))
            .rejects.toThrow('Address not found');
        expect((await addressService.getAddresses(customerId)).items).toHaveLength(1);
    });

    it('rejects unconfigured cities and incomplete coordinate pairs', async () => {
        await expect(addressService.createAddress(customerId, address({ city: 'Unknown' })))
            .rejects.toThrow('City is not configured for delivery');
        await expect(addressService.createAddress(customerId, address({ latitude: 24.7 })))
            .rejects.toThrow('Latitude and longitude must be provided together');
    });

    it('does not mutate an address when an update is invalid', async () => {
        const created = await addressService.createAddress(customerId, address());

        await expect(addressService.updateAddress(customerId, created.id, { phone: 'bad' }))
            .rejects.toThrow('A valid phone number is required');
        expect((await addressService.getAddressById(customerId, created.id)).phone)
            .toBe('+966500000111');
    });

    it('does not resolve a zone belonging to another city', async () => {
        await expect(addressService.resolveDeliveryZone('Riyadh', 'zone-jeddah-central'))
            .rejects.toThrow('No active delivery zone is available for Riyadh');
    });

    it('moves the default when the current default is deleted', async () => {
        const first = await addressService.createAddress(customerId, address());
        const second = await addressService.createAddress(customerId, address({ label: 'Work', isDefault: false }));

        await addressService.deleteAddress(customerId, first.id);

        expect((await addressService.getAddressById(customerId, second.id)).isDefault).toBe(true);
    });
});
