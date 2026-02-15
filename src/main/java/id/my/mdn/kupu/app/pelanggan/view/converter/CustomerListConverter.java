package id.my.mdn.kupu.app.pelanggan.view.converter;

import id.my.mdn.kupu.app.pelanggan.entity.Customer;
import id.my.mdn.kupu.app.pelanggan.dao.CustomerFacade;
import id.my.mdn.kupu.core.base.util.K.KLong;
import id.my.mdn.kupu.core.base.view.converter.SelectionsConverter;
import jakarta.faces.convert.FacesConverter;
import jakarta.inject.Inject;

@FacesConverter(managed = true, value = "CustomerListConverter")
public class CustomerListConverter extends SelectionsConverter<Customer> {

    @Inject
    private CustomerFacade service;

    @Override
    protected Customer getAsObject(String value) {
        return service.find(KLong.valueOf(value));
    }

    @Override
    protected String getAsString(Customer value) {
        return value != null ? String.valueOf(value.getId()) : null;
    }
}
