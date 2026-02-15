package id.my.mdn.kupu.app.pelanggan.view.filter;

import id.my.mdn.kupu.core.base.view.annotation.Bookmark;
import id.my.mdn.kupu.core.base.view.widget.FilterContent;
import jakarta.enterprise.context.Dependent;
import java.io.Serializable;
import id.my.mdn.kupu.app.pelanggan.entity.TariffCategory;

@Dependent
public class CustomerFilter extends FilterContent implements Serializable {
    
    @Bookmark(name = "id")
    private Long id;
    @Bookmark(name = "name")
    private String name;
    @Bookmark(name = "tariffCategory")
    private TariffCategory tariffCategory;
    @Bookmark(name = "rt")
    private String rt;
    @Bookmark(name = "rw")
    private String rw;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public TariffCategory getTariffCategory() { return tariffCategory; }
    public void setTariffCategory(TariffCategory tariffCategory) { this.tariffCategory = tariffCategory; }
    public String getRt() { return rt; }
    public void setRt(String rt) { this.rt = rt; }
    public String getRw() { return rw; }
    public void setRw(String rw) { this.rw = rw; }
}
