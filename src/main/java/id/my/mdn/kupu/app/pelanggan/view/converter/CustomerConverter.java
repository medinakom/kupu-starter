package id.my.mdn.kupu.app.pelanggan.view.converter;

import id.my.mdn.kupu.app.pelanggan.entity.Customer;
import id.my.mdn.kupu.app.pelanggan.dao.CustomerFacade;
import id.my.mdn.kupu.core.base.util.K.KLong;
import jakarta.faces.component.UIComponent;
import jakarta.faces.context.FacesContext;
import jakarta.faces.convert.Converter;
import jakarta.faces.convert.FacesConverter;
import jakarta.inject.Inject;

@FacesConverter(managed = true, value = "CustomerConverter")
public class CustomerConverter implements Converter<Customer> {

    @Inject
    private CustomerFacade dao;

    @Override
    public Customer getAsObject(FacesContext context, UIComponent component, String value) {
        if (value == null || value.isEmpty()) {
            return null;
        }
        return dao.find(KLong.valueOf(value));
    }

    @Override
    public String getAsString(FacesContext context, UIComponent component, Customer value) {
        return value != null ? value.toString() : null;
    }
}
