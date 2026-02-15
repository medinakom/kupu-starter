package id.my.mdn.kupu.app.pelanggan.view;

import id.my.mdn.kupu.app.pelanggan.view.list.CustomerList;
import id.my.mdn.kupu.app.pelanggan.view.admin.CustomerEditorPage;
import id.my.mdn.kupu.core.base.view.Page;
import id.my.mdn.kupu.core.base.view.annotation.Bookmarked;
import id.my.mdn.kupu.core.base.view.annotation.Creator;
import id.my.mdn.kupu.core.base.view.annotation.Editor;
import id.my.mdn.kupu.core.base.view.annotation.Deleter;
import jakarta.annotation.PostConstruct;
import jakarta.faces.view.ViewScoped;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import java.io.Serializable;

@Named(value = "customerPage")
@ViewScoped
public class CustomerPage extends Page implements Serializable {

    @Inject
    @Bookmarked
    private CustomerList dataView;
    
    @Override
    @PostConstruct
    public void init() {
        super.init();
    }

    public CustomerList getDataView() {
        return dataView;
    }

    @Creator(of = "dataView")
    public void openCreator() {
        gotoChild(CustomerEditorPage.class).open();
    }

    @Editor(of = "dataView")
    public void openEditor() {
        gotoChild(CustomerEditorPage.class)
                .addParam("entity")
                .withValues(dataView.getSelected())
                .open();
    }

    @Deleter(of = "dataView")
    public void openDeleter() {
        dataView.deleteSelected();
    }
}
