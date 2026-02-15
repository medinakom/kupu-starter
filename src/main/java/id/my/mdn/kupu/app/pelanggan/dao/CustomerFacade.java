package id.my.mdn.kupu.app.pelanggan.dao;

import id.my.mdn.kupu.app.pelanggan.entity.Customer;
import id.my.mdn.kupu.core.base.dao.AbstractFacade;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;

@ApplicationScoped
public class CustomerFacade extends AbstractFacade<Customer> {

    @PersistenceContext(unitName = "KupuPersistenceUnit")
    private EntityManager em;

    @Override protected EntityManager getEntityManager() { return em; }
    public CustomerFacade() { super(Customer.class); }
}
