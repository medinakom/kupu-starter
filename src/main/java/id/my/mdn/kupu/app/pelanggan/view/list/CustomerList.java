package id.my.mdn.kupu.app.pelanggan.view.list;

import id.my.mdn.kupu.app.pelanggan.dao.CustomerFacade;
import id.my.mdn.kupu.app.pelanggan.entity.Customer;
import id.my.mdn.kupu.app.pelanggan.view.filter.CustomerFilter;
import id.my.mdn.kupu.core.base.dao.AbstractFacade.DefaultChecker;
import id.my.mdn.kupu.core.base.util.FilterTypes.FilterData;
import id.my.mdn.kupu.core.base.util.Result;
import id.my.mdn.kupu.core.base.view.widget.AbstractMutablePagedValueList;
import id.my.mdn.kupu.core.base.view.widget.AbstractPagedValueList.DefaultCount;
import id.my.mdn.kupu.core.base.view.widget.AbstractValueList.DefaultList;
import id.my.mdn.kupu.core.base.view.widget.SorterData;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.Dependent;
import jakarta.inject.Inject;
import java.util.List;
import java.util.Map;

@Dependent
public class CustomerList extends AbstractMutablePagedValueList<Customer> {

    @Inject
    private CustomerFacade dao;

    @Inject
    private CustomerFilter filterContent;

    public CustomerList() {
        super(Customer.class);
    }

    @PostConstruct
    public void init() {
        filter.setContent(filterContent);
    }

    @Override
    protected List<Customer> getPagedFetchedItemsInternal(int first, int pageSize, Map<String, Object> parameters, List<FilterData> filters, List<SorterData> sorters, DefaultList<Customer> defaultList, DefaultChecker defaultChecker) {
        return dao.findAll(first, pageSize, parameters, filters, sorters, defaultList.get(), defaultChecker);
    }

    @Override
    protected long getItemsCountInternal(Map<String, Object> parameters, List<FilterData> filters, DefaultCount defaultCount, DefaultChecker defaultChecker) {
        return dao.countAll(parameters, filters, defaultCount.get(), defaultChecker);
    }

    @Override
    protected Result<String> createInternal(Customer entity) {
        return dao.create(entity);
    }

    @Override
    protected Result<String> editInternal(Customer entity) {
        return dao.edit(entity);
    }

    @Override
    protected Result<String> deleteInternal(Customer entity) {
        return dao.remove(entity);
    }

    @Override
    public String[] getCreatePermission() {
        return new String[]{"pelanggan.customer.create"};
    }

    @Override
    public String[] getUpdatePermission() {
        return new String[]{"pelanggan.customer.update"};
    }

    @Override
    public String[] getDeletePermission() {
        return new String[]{"pelanggan.customer.delete"};
    }
}
