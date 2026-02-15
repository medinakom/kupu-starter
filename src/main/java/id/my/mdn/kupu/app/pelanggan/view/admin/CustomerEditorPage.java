package id.my.mdn.kupu.app.pelanggan.view.admin;

import id.my.mdn.kupu.app.pelanggan.dao.CustomerFacade;
import id.my.mdn.kupu.app.pelanggan.entity.Customer;
import id.my.mdn.kupu.core.base.util.Result;
import id.my.mdn.kupu.core.base.view.FormPage;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ConversationScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;

@Named
@ConversationScoped
public class CustomerEditorPage extends FormPage<Customer> {

    @Inject
    private CustomerFacade dao;

    @PostConstruct
    @Override
    protected void init() {
        super.init();
    }

    @Override
    protected Customer newEntity() {
        return new Customer();
    }

    @Override
    protected Result<String> save(Customer entity) {
        return dao.create(entity);
    }

    @Override
    protected Result<String> edit(Customer entity) {
        return dao.edit(entity);
    }
}
