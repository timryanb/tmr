# For the use of MPI
from mpi4py.libmpi cimport *
cimport mpi4py.MPI as MPI

# Import numpy 
cimport numpy as np
import numpy as np

# Ensure that numpy is initialized
np.import_array()

# Import the definition required for const strings
from libc.string cimport const_char
from libc.stdlib cimport malloc, free

# Import C methods for python
from cpython cimport PyObject, Py_INCREF

# Import the TACS module
from tacs.TACS cimport *
from tacs.elements cimport *

# Import the definitions
from TMR cimport *

# Include the mpi4py header
cdef extern from "mpi-compat.h":
    pass

# Wrap interface for TACSTopoCreator
cdef void _createelements( void *_self, int order, TMROctForest *forest,
                           int num_elements, TACSElement** elements ):
    pf = _init_OctForest(forest)
    e = []
    for i in range(num_elements):
        e.append(_init_Element(elements[i]))
    (<object>_self).createElements(order,pf,num_elements, e)
    
    return

# Wrap the creator class
cdef class pyTMROctTACSTopoCreator:
    cdef CyTMROctTACSTopoCreator *this_ptr
    def __init__(self, BoundaryConditions bcs,
                 OctStiffnessProperties props, OctForest  filter,
                 char* shell_attr=None, SolidShell shell=None):
        cdef SolidShellWrapper *cshell = NULL
        if shell:
            cshell = shell.ptr
        
        self.this_ptr = new CyTMROctTACSTopoCreator(bcs.ptr,props.ptr, filter.ptr,
                                                    shell_attr, cshell)
        self.this_ptr.setSelfPointer(<void*>self)
        self.this_ptr.setCreateElements(_createelements)
        return

    def __dealloc__(self):
        if (self.this_ptr):
            del self.this_ptr
        return

cdef class SolidShell:
    cdef SolidShellWrapper *ptr
                 

# This wraps a C++ array with a numpy array for later useage
cdef inplace_array_1d(int nptype, int dim1, void *data_ptr,
                      PyObject *ptr):
    '''Return a numpy version of the array'''
    # Set the shape of the array
    cdef int size = 1
    cdef np.npy_intp shape[1]
    cdef np.ndarray ndarray

    # Set the first entry of the shape array
    shape[0] = <np.npy_intp>dim1
      
    # Create the array itself - Note that this function will not
    # delete the data once the ndarray goes out of scope
    ndarray = np.PyArray_SimpleNewFromData(size, shape,
                                           nptype, data_ptr)

    # Set the base class who owns the memory
    if ptr != NULL:
        ndarray.base = ptr

    return ndarray

cdef class Vertex:
    cdef TMRVertex *ptr
    def __cinit__(self):
        self.ptr = NULL
        
    def __dealloc__(self):
        if self.ptr:
            self.ptr.decref()

    def evalPoint(self):
        cdef TMRPoint pt
        self.ptr.evalPoint(&pt)
        return np.array([pt.x, pt.y, pt.z])

    def setAttribute(self, char *name):
        if self.ptr:
            self.ptr.setAttribute(name)

    def getEntityId(self):
        if self.ptr:
            return self.ptr.getEntityId()
        return -1

    def setNodeNum(self, num):
        cdef int n = num
        self.ptr.setNodeNum(&n)
        return n

cdef _init_Vertex(TMRVertex *ptr):
    vertex = Vertex()
    vertex.ptr = ptr
    vertex.ptr.incref()
    return vertex

cdef class Edge:
    cdef TMREdge *ptr
    def __cinit__(self):
        self.ptr = NULL
      
    def __dealloc__(self):
        if self.ptr:
            self.ptr.decref()

    def setAttribute(self, char *name):
        if self.ptr:
            self.ptr.setAttribute(name)

    def getEntityId(self):
        if self.ptr:
            return self.ptr.getEntityId()
        return -1

    def setVertices(self, Vertex v1, Vertex v2):
        self.ptr.setVertices(v1.ptr, v2.ptr)

    def getVertices(self):
        cdef TMRVertex *v1 = NULL
        cdef TMRVertex *v2 = NULL
        self.ptr.getVertices(&v1, &v2)
        return _init_Vertex(v1), _init_Vertex(v2)
   
    def writeToVTK(self, char* filename):
        self.ptr.writeToVTK(filename)

    def setSource(self, Edge e):
        self.ptr.setSource(e.ptr)

    def getSource(self):
        cdef TMREdge *e
        self.ptr.getSource(&e)
        return _init_Edge(e)
    
    def setMesh(self, EdgeMesh mesh):
        self.ptr.setMesh(mesh.ptr)

    def writeToVTK(self, char *filename):
        self.ptr.writeToVTK(filename)

cdef _init_Edge(TMREdge *ptr):
    edge = Edge()
    edge.ptr = ptr
    edge.ptr.incref()
    return edge

cdef class EdgeLoop:
    cdef TMREdgeLoop *ptr
    def __cinit__(self, list edges=None, list dirs=None):
        cdef int nedges = 0
        cdef TMREdge **e = NULL
        cdef int *d = NULL
        self.ptr = NULL

        if (edges is not None and dirs is not None and
            len(edges) == len(dirs)):
            nedges = len(edges)
            e = <TMREdge**>malloc(nedges*sizeof(TMREdge*))
            d = <int*>malloc(nedges*sizeof(int))
            for i in range(nedges):
                e[i] = (<Edge>edges[i]).ptr
                d[i] = <int>dirs[i]
            
            self.ptr = new TMREdgeLoop(nedges, e, d)
            self.ptr.incref()
            free(e)
            free(d)

    def __decalloc__(self):
        if self.ptr:
            self.ptr.decref()

    def getEntityId(self):
        if self.ptr:
            return self.ptr.getEntityId()
        return -1

    def getEdgeLoop(self):
        cdef int nedges = 0
        cdef TMREdge **edges = NULL
        cdef const int *dirs = NULL
        self.ptr.getEdgeLoop(&nedges, &edges, &dirs)
        e = []
        d = []
        for i in range(nedges):
            e.append(_init_Edge(edges[i]))
            d.append(dirs[i])
        return e, d        

cdef _init_EdgeLoop(TMREdgeLoop *ptr):
    loop = EdgeLoop()
    loop.ptr = ptr
    loop.ptr.incref()
    return loop

cdef class Face:
    cdef TMRFace *ptr
    def __cinit__(self):
        self.ptr = NULL
      
    def __dealloc__(self):
        if self.ptr:
            self.ptr.decref()
         
    def setAttribute(self, char *name):
        if self.ptr:
            self.ptr.setAttribute(name)

    def getEntityId(self):
        if self.ptr:
            return self.ptr.getEntityId()
        return -1

    def getNumEdgeLoops(self):
        return self.ptr.getNumEdgeLoops()

    def addEdgeLoop(self, EdgeLoop loop):
        self.ptr.addEdgeLoop(loop.ptr)

    def getEdgeLoop(self, k):
        cdef TMREdgeLoop *loop = NULL
        self.ptr.getEdgeLoop(k, &loop)
        if loop:
            return _init_EdgeLoop(loop)
        return None
    
    def setSource(self, Volume v, Face f):
        self.ptr.setSource(v.ptr, f.ptr)

    def getSource(self):
        cdef TMRFace *f
        cdef TMRVolume *v
        cdef int d
        self.ptr.getSource(&d, &v, &f)
        return d, _init_Volume(v), _init_Face(f)

    def setMesh(self, FaceMesh mesh):
        self.ptr.setMesh(mesh.ptr)

    def writeToVTK(self, char *filename):
        self.ptr.writeToVTK(filename)
      
cdef _init_Face(TMRFace *ptr):
    face = Face()
    face.ptr = ptr
    face.ptr.incref()
    return face

cdef class Volume:
    cdef TMRVolume *ptr
    def __cinit__(self, list faces=None, list dirs=None):
        cdef int nfaces = 0
        cdef int *d = NULL
        cdef TMRFace **f = NULL
        self.ptr = NULL
        if (faces is not None and dirs is not None and
            len(faces) == len(dirs)):
            nfaces = len(faces)
            d = <int*>malloc(nfaces*sizeof(int))
            f = <TMRFace**>malloc(nfaces*sizeof(TMRFace*))
            for i in range(nfaces):
                f[i] = (<Face>faces[i]).ptr
                d[i] = <int>dirs[i]
            self.ptr = new TMRVolume(nfaces, f, d)
            self.ptr.incref()
            free(d)
            free(f)
      
    def __dealloc__(self):
        if self.ptr:
            self.ptr.decref()

    def setAttribute(self, char *name):
        if self.ptr:
            self.ptr.setAttribute(name)

    def getEntityId(self):
        if self.ptr:
            return self.ptr.getEntityId()
        return -1

    def getFaces(self):
        cdef TMRFace **f
        cdef int num_faces = 0
        if self.ptr:
            self.ptr.getFaces(&num_faces, &f, NULL)
        faces = []
        for i in xrange(num_faces):
            faces.append(_init_Face(f[i]))
        return faces
   
    def writeToVTK(self, char* filename):
        self.ptr.writeToVTK(filename)

cdef _init_Volume(TMRVolume *ptr):
    vol = Volume()
    vol.ptr = ptr
    vol.ptr.incref()
    return vol

cdef class Curve:
    cdef TMRCurve *ptr
    def __cinit__(self):
        self.ptr = NULL
        
    def __dealloc__(self):
        if self.ptr:
            self.ptr.decref()

    def setAttribute(self, char *name):
        if self.ptr:
            self.ptr.setAttribute(name)
            
    def getEntityId(self):
        if self.ptr:
            return self.ptr.getEntityId()
        return -1

    def writeToVTK(self, char* filename):
        self.ptr.writeToVTK(filename)

cdef _init_Curve(TMRCurve *ptr):
    curve = Curve()
    curve.ptr = ptr
    curve.ptr.incref()
    return curve

cdef class Pcurve:
    cdef TMRPcurve *ptr
    def __cinit__(self):
        self.ptr = NULL
        
    def __dealloc__(self):
        if self.ptr:
            self.ptr.decref()

    def setAttribute(self, char *name):
        if self.ptr:
            self.ptr.setAttribute(name)

    def getEntityId(self):
        if self.ptr:
            return self.ptr.getEntityId()
        return -1

cdef class Surface:
    cdef TMRSurface *ptr
    def __cinit__(self):
        self.ptr = NULL
        
    def __dealloc__(self):
        if self.ptr:
            self.ptr.decref()
            
    def setAttribute(self, char *name):
        if self.ptr:
            self.ptr.setAttribute(name)

    def writeToVTK(self, char* filename):
        self.ptr.writeToVTK(filename)

cdef _init_Surface(TMRSurface *ptr):
    surface = Surface()
    surface.ptr = ptr
    surface.ptr.incref()
    return surface

cdef class BsplineCurve(Curve):
    def __cinit__(self, np.ndarray[double, ndim=2, mode='c'] pts, int k=4):
        cdef int nctl = pts.shape[0]
        cdef ku = k
        if ku > nctl:
            ku = nctl
        cdef TMRPoint* p = <TMRPoint*>malloc(nctl*sizeof(TMRPoint))
        for i in range(nctl):
            p[i].x = pts[i,0]
            p[i].y = pts[i,1]
            p[i].z = pts[i,2]
        self.ptr = new TMRBsplineCurve(nctl, ku, p)
        self.ptr.incref()
        free(p)

cdef class BsplinePcurve(Pcurve):
    def __cinit__(self, np.ndarray[double, ndim=2, mode='c'] pts, int k=4):
        cdef int nctl = pts.shape[0]
        cdef ku = k
        if ku > nctl:
            ku = nctl
        self.ptr = new TMRBsplinePcurve(nctl, ku, <double*>pts.data)
        self.ptr.incref()

cdef class BsplineSurface(Surface):
    def __cinit__(self, np.ndarray[double, ndim=3, mode='c'] pts,
                  int ku=4, int kv=4):
        cdef int nx = pts.shape[0]
        cdef int ny = pts.shape[1]
        cdef kx = ku
        cdef ky = kv
        if kx > nx:
            kx = nx
        if ky > ny:
            ky = ny
        cdef TMRPoint* p = <TMRPoint*>malloc(nx*ny*sizeof(TMRPoint))
        for j in range(ny):
            for i in range(nx):
                p[i + j*nx].x = pts[i,j,0]
                p[i + j*nx].y = pts[i,j,1]
                p[i + j*nx].z = pts[i,j,2]
        self.ptr = new TMRBsplineSurface(nx, ny, kx, ky, p)
        self.ptr.incref()
        free(p)

cdef class VertexFromPoint(Vertex):
    def __cinit__(self, np.ndarray[double, ndim=1, mode='c'] pt):
        cdef TMRPoint point
        point.x = pt[0]
        point.y = pt[1]
        point.z = pt[2]
        self.ptr = new TMRVertexFromPoint(point)
        self.ptr.incref()

cdef class VertexFromEdge(Vertex):
    def __cinit__(self, Edge edge, double t):
        self.ptr = new TMRVertexFromEdge(edge.ptr, t)
        self.ptr.incref()

cdef class VertexFromFace(Vertex):
    def __cinit__(self, Face face, double u, double v):
        self.ptr = new TMRVertexFromFace(face.ptr, u, v)
        self.ptr.incref()

cdef class EdgeFromFace(Edge):
    def __cinit__(self, Face face, Pcurve pcurve, int degen=0):
        self.ptr = new TMREdgeFromFace(face.ptr, pcurve.ptr, degen)
        self.ptr.incref()

    def addEdgeFromFace(self, Face face, Pcurve pcurve):
        cdef TMREdgeFromFace *ef = NULL
        ef = _dynamicEdgeFromFace(self.ptr)
        if ef:
            ef.addEdgeFromFace(face.ptr, pcurve.ptr)

cdef class EdgeFromCurve(Edge):
    def __cinit__(self, Curve curve):
        self.ptr = new TMREdgeFromCurve(curve.ptr)
        self.ptr.incref()

cdef class FaceFromSurface(Face):
    def __cinit__(self, Surface surf):
        self.ptr = new TMRFaceFromSurface(surf.ptr)
        self.ptr.incref()

cdef class TFIFace(Face):
    def __cinit__(self, list edges, list dirs, list verts):
        cdef TMREdge *e[4]
        cdef int d[4]
        cdef TMRVertex *v[4]
        assert(len(edges) == 4 and len(dirs) == 4 and len(verts) == 4)
        for i in range(4):
            e[i] = (<Edge>edges[i]).ptr
            v[i] = (<Vertex>verts[i]).ptr
            d[i] = <int>dirs[i]
        self.ptr = new TMRTFIFace(e, d, v)
        self.ptr.incref()

cdef class CurveInterpolation:
    cdef TMRCurveInterpolation *ptr
    def __cinit__(self, np.ndarray[double, ndim=2, mode='c'] pts):
        cdef int nctl = pts.shape[0]
        cdef TMRPoint* p = <TMRPoint*>malloc(nctl*sizeof(TMRPoint))
        for i in range(nctl):
            p[i].x = pts[i,0]
            p[i].y = pts[i,1]
            p[i].z = pts[i,2]
        self.ptr = new TMRCurveInterpolation(p, nctl)
        self.ptr.incref()
        free(p)

    def __dealloc__(self):
        if self.ptr:
            self.ptr.decref()

    def setNumControlPoints(self, int nctl):
        self.ptr.setNumControlPoints(nctl)
        return

    def createCurve(self, int ku):
        cdef TMRBsplineCurve *curve = self.ptr.createCurve(ku)
        return _init_Curve(curve)

cdef class CurveLofter:
    cdef TMRCurveLofter *ptr
    def __cinit__(self, curves):
        cdef int ncurves = len(curves)
        cdef TMRBsplineCurve **crvs = NULL
        cdef TMRBsplineCurve *bspline = NULL
        crvs = <TMRBsplineCurve**>malloc(ncurves*sizeof(TMRBsplineCurve*))
        for i in range(ncurves):
            bspline =  _dynamicBsplineCurve((<Curve>curves[i]).ptr)
            if bspline != NULL:
               crvs[i] = bspline
            else:
               raise ValueError('CurveLofter: Lofting curves must be BsplineCurves')
        self.ptr = new TMRCurveLofter(crvs, ncurves)
        self.ptr.incref()
        free(crvs)

    def __dealloc__(self):
        if self.ptr:
            self.ptr.decref()

    def createSurface(self, int kv):
        cdef TMRSurface *surf = self.ptr.createSurface(kv)
        return _init_Surface(surf)

cdef class Model:
    cdef TMRModel *ptr
    def __cinit__(self, verts=None, edges=None, faces=None, vols=None):
        # Set the pointer to NULL
        self.ptr = NULL

        cdef int nverts = 0
        cdef TMRVertex **v = NULL
        if verts is not None:
            nverts = len(verts)
            v = <TMRVertex**>malloc(nverts*sizeof(TMRVertex*))
            for i in xrange(len(verts)):
                v[i] = (<Vertex>verts[i]).ptr

        cdef int nedges = 0
        cdef TMREdge **e = NULL
        if edges is not None:
            nedges = len(edges)
            e = <TMREdge**>malloc(nedges*sizeof(TMREdge*))
            for i in xrange(len(edges)):
                e[i] = (<Edge>edges[i]).ptr

        cdef int nfaces = 0
        cdef TMRFace **f = NULL
        if faces is not None:
            nfaces = len(faces)
            f = <TMRFace**>malloc(nfaces*sizeof(TMRFace*))
            for i in xrange(len(faces)):
                f[i] = (<Face>faces[i]).ptr

        cdef int nvols = 0
        cdef TMRVolume **b = NULL
        if vols is not None:
            nvols = len(vols)
            b = <TMRVolume**>malloc(nvols*sizeof(TMRVolume*))
            for i in xrange(len(vols)):
                b[i] = (<Volume>vols[i]).ptr

        if v and e and f and b:
            self.ptr = new TMRModel(nverts, v, nedges, e, nfaces, f, nvols, b)
        elif v and e and f:
            self.ptr = new TMRModel(nverts, v, nedges, e, nfaces, f, 0, NULL)
        elif v and e:
            self.ptr = new TMRModel(nverts, v, nedges, e, 0, NULL, 0, NULL)

        if self.ptr:
            self.ptr.incref()

        if v: free(v)
        if e: free(e)
        if f: free(f)
        if b: free(b)
        return
  
    def __dealloc__(self):
        if self.ptr:
            self.ptr.decref()
   
    def getVolumes(self):
        cdef TMRVolume **vol
        cdef int num_vol = 0
        if self.ptr:
            self.ptr.getVolumes(&num_vol, &vol)
        volumes = []
        for i in xrange(num_vol):
            volumes.append(_init_Volume(vol[i]))
        return volumes

    def getFaces(self):
        cdef TMRFace **f
        cdef int num_faces = 0
        if self.ptr:
            self.ptr.getFaces(&num_faces, &f)
        faces = []
        for i in xrange(num_faces):
            faces.append(_init_Face(f[i]))
        return faces

    def getEdges(self):
        cdef TMREdge **e
        cdef int num_edges = 0
        if self.ptr:
            self.ptr.getEdges(&num_edges, &e)
        edges = []
        for i in xrange(num_edges):
            edges.append(_init_Edge(e[i]))
        return edges

    def getVertices(self):
        cdef TMRVertex **v
        cdef int num_verts = 0
        if self.ptr:
            self.ptr.getVertices(&num_verts, &v)
        verts = []
        for i in xrange(num_verts):
            verts.append(_init_Vertex(v[i]))
        return verts

    def writeEdgeLoopsToTecplot(self, char *fname):
        '''Write a representation of the edge loops to a file'''
        fp = open(fname, 'w')
        fp.write('Variables = x, y, z, tx, ty, tz\n')

        faces = self.getFaces()
        index = 0
        for f in faces:
            for k in range(f.getNumEdgeLoops()):
                fp.write('Zone T = \"Face %d Loop %d\"\n'%(index, k))

                loop = f.getEdgeLoop(k)
                e, dirs = loop.getEdgeLoop()
                pts = np.zeros((len(e)+1, 3))
                tx = np.zeros((len(e)+1, 3))
                for i in range(len(e)):
                    v1, v2 = e[i].getVertices()
                    if dirs[i] > 0:
                        pt1 = v1.evalPoint()
                        pt2 = v2.evalPoint()
                    else:
                        pt1 = v2.evalPoint()
                        pt2 = v1.evalPoint()
                    if i == 0:
                        pts[0,:] = pt1[:]
                    pts[i+1,:] = pt2[:]

                for i in xrange(len(e)):
                    tx[i,:] = pts[i+1,:] - pts[i,:]
                
                for i in xrange(len(e)+1):
                    fp.write('%e %e %e %e %e %e\n'%(
                        pts[i,0], pts[i,1], pts[i,2], 
                        tx[i,0], tx[i,1], tx[i,2]))
            index += 1
        return
        
cdef _init_Model(TMRModel* ptr):
    model = Model()
    model.ptr = ptr
    model.ptr.incref()
    return model

cdef class MeshOptions:
    cdef TMRMeshOptions ptr
    def __cinit__(self):
        self.ptr = TMRMeshOptions()
      
    def __dealloc__(self):
        return
   
    property num_smoothing_steps:
        def __get__(self):
            return self.ptr.num_smoothing_steps
        def __set__(self, value):
            self.ptr.num_smoothing_steps=value

    property frontal_quality_factor:
        def __get__(self):
            return self.ptr.frontal_quality_factor
        def __set__(self, value):
            self.ptr.frontal_quality_factor = value

    property triangularize_print_level:
        def __get__(self):
            return self.ptr.triangularize_print_level
        def __set__(self, value):
            self.ptr.triangularize_print_level = value

    property triangularize_print_iter:
        def __get__(self):
            return self.ptr.triangularize_print_iter
        def __set__(self, value):
            if value >= 1:
                self.ptr.triangularize_print_iter = value

    property write_mesh_quality_histogram:
        def __get__(self):
            return self.ptr.write_mesh_quality_histogram
        def __set__(self, value):
            self.ptr.write_mesh_quality_histogram = value

    property write_init_domain_triangle:
        def __get__(self):
            return self.ptr.write_init_domain_triangle
        def __set__(self, value):
            self.ptr.write_init_domain_triangle = value

    property write_triangularize_intermediate:
        def __get__(self):
            return self.ptr.write_triangularize_intermediate
        def __set__(self, value):
            self.ptr.write_triangularize_intermediate = value

    property write_pre_smooth_triangle:
        def __get__(self):
            return self.ptr.write_pre_smooth_triangle
        def __set__(self, value):
            self.ptr.write_pre_smooth_triangle = value

    property write_post_smooth_triangle:
        def __get__(self):
            return self.ptr.write_post_smooth_triangle
        def __set__(self, value):
            self.ptr.write_post_smooth_triangle = value

    property write_dual_recombine:
        def __get__(self):
            return self.ptr.write_dual_recombine
        def __set__(self, value):
            self.ptr.write_dual_recombine = value

    property write_pre_smooth_quad:
        def __get__(self):
            return self.ptr.write_pre_smooth_quad
        def __set__(self, value):
            self.ptr.write_pre_smooth_quad = value

    property write_post_smooth_quad:
        def __get__(self):
            return self.ptr.write_post_smooth_quad
        def __set__(self, value):
            self.ptr.write_post_smooth_quad = value

    property write_quad_dual:
        def __get__(self):
            return self.ptr.write_quad_dual
        def __set__(self, value):
            self.ptr.write_quad_dual = value

   # @property for cython 0.26 and above
   # def num_smoothing_steps(self):
   #    return self.ptr.num_smoothing_steps
   # @num_smoothing_steps.setter
   # def num_smoothing_steps(self,value):
   #    self.ptr.num_smoothing_steps = value

cdef class ElementFeatureSize:
    cdef TMRElementFeatureSize *ptr
    def __cinit__(self, *args, **kwargs):
        self.ptr = NULL

    def __dealloc__(self):
        if self.ptr:
            self.ptr.decref()

cdef class ConstElementSize(ElementFeatureSize):
    def __cinit__(self, double h):
        self.ptr = new TMRElementFeatureSize(h)
        self.ptr.incref()

cdef class LinearElementSize(ElementFeatureSize):
    def __cinit__(self, double hmin, double hmax,
                  double c=0.0, double ax=0.0, double ay=0.0, double az=0.0):
        self.ptr = new TMRLinearElementSize(hmin, hmax, c, ax, ay, az)
        self.ptr.incref()
        
cdef class Mesh:
    cdef TMRMesh *ptr
    def __cinit__(self, MPI.Comm comm, Model geo):
        cdef MPI_Comm c_comm = NULL
        self.ptr = NULL
        if comm is not None:
            c_comm = comm.ob_mpi
            self.ptr = new TMRMesh(c_comm, geo.ptr)
            self.ptr.incref()

    def __dealloc__(self):
        if self.ptr:
            self.ptr.decref()

    def mesh(self, double h=1.0, MeshOptions opts=None,
             ElementFeatureSize fs=None):
        cdef TMRMeshOptions default
        if fs is not None:
            if opts is None:
                self.ptr.mesh(default, fs.ptr)
            else:
                self.ptr.mesh(opts.ptr, fs.ptr)
        else:
            if opts is None:
                self.ptr.mesh(default, h)
            else:
                self.ptr.mesh(opts.ptr, h)

    def getMeshPoints(self):
        cdef TMRPoint *X
        cdef int npts = 0
        npts = self.ptr.getMeshPoints(&X)
        Xp = np.zeros((npts, 3), dtype=np.double)
        for i in range(npts):
            Xp[i,0] = X[i].x
            Xp[i,1] = X[i].y
            Xp[i,2] = X[i].z
        return Xp

    def getMeshConnectivity(self):
        cdef const int *quads = NULL
        cdef const int *hexes = NULL
        cdef int nquads = 0
        cdef int nhexes = 0
        self.ptr.getMeshConnectivity(&nquads, &quads,
                                     &nhexes, &hexes)
       
        q = np.zeros((nquads, 4), dtype=np.intc)
        for i in range(nquads):
            q[i,0] = quads[4*i]
            q[i,1] = quads[4*i+1]
            q[i,2] = quads[4*i+2]
            q[i,3] = quads[4*i+3]
          
        he = np.zeros((nhexes,8), dtype=np.intc)
        for i in range(nhexes):
            he[i,0] = hexes[8*i]
            he[i,1] = hexes[8*i+1]
            he[i,2] = hexes[8*i+2]
            he[i,3] = hexes[8*i+3]
            he[i,4] = hexes[8*i+4]
            he[i,5] = hexes[8*i+5]
            he[i,6] = hexes[8*i+6]
            he[i,7] = hexes[8*i+7]
          
        return q, he

    def createModelFromMesh(self):
        cdef TMRModel *model = NULL
        model = self.ptr.createModelFromMesh()
        return _init_Model(model) 

    def writeToBDF(self, char *filename, outtype=None):
        # Write both quads and hexes
        cdef int flag = 3
        if outtype is None:
            flag = 3
        elif outtype == 'quad':
            flag = 1
        elif outtype == 'hex':
            flag = 2
        self.ptr.writeToBDF(filename, flag)

    def writeToVTK(self, char *filename, outtype=None):
        # Write both quads and hexes
        cdef int flag = 3
        if outtype is None:
            flag = 3
        elif outtype == 'quad':
            flag = 1
        elif outtype == 'hex':
            flag = 2
        self.ptr.writeToVTK(filename, flag)

cdef class EdgeMesh:
    cdef TMREdgeMesh *ptr
    def __cinit__(self, MPI.Comm comm, Edge e):
        cdef MPI_Comm c_comm = comm.ob_mpi        
        self.ptr = new TMREdgeMesh(c_comm, e.ptr)
        self.ptr.incref()

    def __dealloc__(self):
        pass
    
    def mesh(self, double h, MeshOptions opts=None):
        cdef TMRMeshOptions options
        cdef TMRElementFeatureSize *fs = NULL
        fs = new TMRElementFeatureSize(h)
        fs.incref()
        if opts is None:            
            self.ptr.mesh(options, fs)
        else:
            self.ptr.mesh(opts.ptr, fs)
        fs.decref()

cdef class FaceMesh:
    cdef TMRFaceMesh *ptr
    def __cinit__(self, MPI.Comm comm, Face f):
        cdef MPI_Comm c_comm = comm.ob_mpi        
        self.ptr = new TMRFaceMesh(c_comm, f.ptr)
        self.ptr.incref()

    def __dealloc__(self):
        pass

    def mesh(self, double h, MeshOptions opts=None):
        cdef TMRMeshOptions options
        cdef TMRElementFeatureSize *fs = NULL
        fs = new TMRElementFeatureSize(h)
        fs.incref()
        if opts is None:            
            self.ptr.mesh(options, fs)
        else:
            self.ptr.mesh(opts.ptr, fs)
        fs.decref()

cdef class Topology:
    cdef TMRTopology *ptr
    def __cinit__(self, MPI.Comm comm=None, Model m=None):
        cdef MPI_Comm c_comm = NULL
        cdef TMRModel *model = NULL
        self.ptr = NULL
        if comm is not None and m is not None:
            c_comm = comm.ob_mpi
            model = m.ptr
            self.ptr = new TMRTopology(c_comm, model)
            self.ptr.incref()

    def __dealloc__(self):
        if self.ptr:
            self.ptr.decref()

cdef class QuadrantArray:
    cdef TMRQuadrantArray *ptr
    def __cinit__(self):
        self.ptr = NULL

    def __dealloc__(self):
        del self.ptr

cdef _init_QuadrantArray(TMRQuadrantArray *array):
    arr = QuadrantArray()
    arr.ptr = array
    return arr

cdef class QuadForest:
    cdef TMRQuadForest *ptr
    def __cinit__(self, MPI.Comm comm=None):
        cdef MPI_Comm c_comm = NULL
        self.ptr = NULL
        if comm is not None:
            c_comm = comm.ob_mpi
            self.ptr = new TMRQuadForest(c_comm)
            self.ptr.incref()

    def __dealloc__(self):
        if self.ptr:
            self.ptr.decref()

    def setTopology(self, Topology topo):
        self.ptr.setTopology(topo.ptr)

    def repartition(self):
        self.ptr.repartition()

    def createTrees(self, int depth):
        self.ptr.createTrees(depth)

    def createRandomTrees(self, int nrand=10, int min_lev=0, int max_lev=8):
        self.ptr.createRandomTrees(nrand, min_lev, max_lev)

    def refine(self, np.ndarray[int, ndim=1, mode='c'] refine):
        self.ptr.refine(<int*>refine.data)

    def duplicate(self):
        cdef TMRQuadForest *dup = NULL
        dup = self.ptr.duplicate()
        return _init_QuadForest(dup)

    def coarsen(self):
        cdef TMRQuadForest *dup = NULL
        dup = self.ptr.coarsen()
        return _init_QuadForest(dup)

    def balance(self, int btype):
        self.ptr.balance(btype)

    def createNodes(self, int order):
        self.ptr.createNodes(order)

    def getQuadsWithAttribute(self, char *attr):
        cdef TMRQuadrantArray *array = NULL
        array = self.ptr.getQuadsWithAttribute(attr)
        return _init_QuadrantArray(array)

    def getNodesWithAttribute(self, char *attr):
        cdef TMRQuadrantArray *array = NULL
        array = self.ptr.getNodesWithAttribute(attr)
        return _init_QuadrantArray(array)

    def getNodeRange(self):
        cdef int size = 0
        cdef const int *node_range = NULL
        size = self.ptr.getOwnedNodeRange(&node_range)
        r = np.zeros(size+1, dtype=np.intc)
        for i in range(size+1):
            r[i] = node_range[i]
        return r

    def createMeshConn(self):
        cdef int *conn
        cdef int nelems
        cdef int order = self.ptr.getMeshOrder()
        self.ptr.createMeshConn(&conn, &nelems)
        quads = np.zeros((nelems, order*order), dtype=np.intc)
        if order == 2:
            for i in range(nelems):
                quads[i,0] = conn[4*i]
                quads[i,1] = conn[4*i+1]
                quads[i,2] = conn[4*i+2]
                quads[i,3] = conn[4*i+3]
        elif order == 3:
            for i in range(nelems):
                quads[i,0] = conn[4*i]
                quads[i,1] = conn[4*i+1]
                quads[i,2] = conn[4*i+2]
                quads[i,3] = conn[4*i+3]
                quads[i,4] = conn[4*i+4]
                quads[i,5] = conn[4*i+5]
                quads[i,6] = conn[4*i+6]
                quads[i,7] = conn[4*i+7]
                quads[i,8] = conn[4*i+8]            
        _deleteMe(conn)
        return quads

    def createDepNodeConn(self):
        self.ptr.createDepNodeConn()

    def getDepNodeConn(self):
        cdef int ndep = 0
        cdef const int *_ptr = NULL
        cdef const int *_conn = NULL
        cdef const double *_weights = NULL
        ndep = self.ptr.getDepNodeConn(&_ptr, &_conn, &_weights)
        ptr = np.zeros(ndep+1, dtype=np.intc)
        conn = np.zeros(_ptr[ndep], dtype=np.intc)
        weights = np.zeros(_ptr[ndep], dtype=np.double)
        for i in range(ndep+1):
            ptr[i] = _ptr[i]
        for i in xrange(ptr[ndep]):
            conn[i] = _conn[i]
            weights[i] = _weights[i]
        return ptr, conn, weights
            
    def writeToVTK(self, char *filename):
        self.ptr.writeToVTK(filename)

    def writeForestToVTK(self, char *filename):
        self.ptr.writeForestToVTK(filename)

cdef _init_QuadForest(TMRQuadForest* ptr):
    forest = QuadForest()
    forest.ptr = ptr
    forest.ptr.incref()
    return forest
 
cdef class OctantArray:
    cdef TMROctantArray *ptr
    def __cinit__(self):
        self.ptr = NULL

    def __dealloc__(self):
        if self.ptr:
            del self.ptr

cdef _init_OctantArray(TMROctantArray *array):
    arr = OctantArray()
    arr.ptr = array
    return arr

cdef class OctForest:
    cdef TMROctForest *ptr
    def __cinit__(self, MPI.Comm comm=None):
        cdef MPI_Comm c_comm = NULL
        self.ptr = NULL
        if comm is not None:
            c_comm = comm.ob_mpi
            self.ptr = new TMROctForest(c_comm)
            self.ptr.incref()

    def __dealloc__(self):
        if self.ptr:
            self.ptr.decref()

    def setTopology(self, Topology topo):
        self.ptr.setTopology(topo.ptr)

    def repartition(self):
        self.ptr.repartition()

    def createTrees(self, int depth):
        self.ptr.createTrees(depth)

    def createRandomTrees(self, int nrand=10, int min_lev=0, int max_lev=8):
        self.ptr.createRandomTrees(nrand, min_lev, max_lev)

    def refine(self, np.ndarray[int, ndim=1, mode='c'] _refine):
        self.ptr.refine(<int*>_refine.data)

    def duplicate(self):
        cdef TMROctForest *dup = NULL
        dup = self.ptr.duplicate()
        return _init_OctForest(dup)

    def coarsen(self):
        cdef TMROctForest *dup = NULL
        dup = self.ptr.coarsen()
        return _init_OctForest(dup)

    def balance(self, int btype):
        self.ptr.balance(btype)

    def createNodes(self, int order):
        self.ptr.createNodes(order)

    def getOctsWithAttribute(self, char *attr):
        cdef TMROctantArray *array = NULL
        array = self.ptr.getOctsWithAttribute(attr)
        return _init_OctantArray(array)

    def getNodesWithAttribute(self, char *attr):
        cdef TMROctantArray *array = NULL
        array = self.ptr.getNodesWithAttribute(attr)
        return _init_OctantArray(array)

    def writeToVTK(self, char *filename):
        self.ptr.writeToVTK(filename)

    def writeForestToVTK(self, char *filename):
        self.ptr.writeForestToVTK(filename)

cdef _init_OctForest(TMROctForest* ptr):
    forest = OctForest()
    forest.ptr = ptr
    forest.ptr.incref()
    return forest

def LoadModel(char *filename, int print_lev=0):
    cdef TMRModel *model = TMR_LoadModelFromSTEPFile(filename, print_lev)
    return _init_Model(model)
   
cdef class BoundaryConditions:
    cdef TMRBoundaryConditions* ptr

    def __cinit__(self):
        self.ptr = new TMRBoundaryConditions()
        self.ptr.incref()

    def __dealloc__(self):
        self.ptr.decref()

    def getNumBoundaryConditions(self):
        return self.ptr.getNumBoundaryConditions()
   
    def addBoundaryCondition(self,  char* attr,
                             int num_bc,
                             np.ndarray[int, ndim=1, mode='c'] bc_nums,
                             np.ndarray[TacsScalar, ndim=1, mode='c'] bc_vals):
        if bc_vals is None:
            self.ptr.addBoundaryCondition(attr, num_bc,
                                          <int*>bc_nums.data,
                                          NULL)
        else:
            self.ptr.addBoundaryCondition(attr, num_bc,
                                          <int*>bc_nums.data,
                                          <TacsScalar*>bc_vals.data)
        return

cdef class OctStiffnessProperties:
    cdef TMRStiffnessProperties ptr
    def __cinit__(self):
        self.ptr = TMRStiffnessProperties()
      
    def __dealloc__(self):
        return
   
    property rho:
        def __get__(self):
            return self.ptr.rho
        def __set__(self,value):
            self.ptr.rho = value

    property E:
        def __get__(self):
            return self.ptr.E
        def __set__(self,value):
            self.ptr.E = value

    property nu:
        def __get__(self):
            return self.ptr.nu
        def __set__(self,value):
            self.ptr.nu = value

    property q:
        def __get__(self):
            return self.ptr.q
        def __set__(self,value):
            self.ptr.q = value

def createMg(list assemblers, list forests):
    cdef int nlevels = 0
    cdef TACSAssembler **assm = NULL
    cdef TMRQuadForest **forst = NULL
    cdef TACSMg *mg = NULL
    
    assert(len(assemblers) == len(forests))
    nlevels = len(assemblers)
    assm = <TACSAssembler**>malloc(nlevels*sizeof(TACSAssembler*))
    forst = <TMRQuadForest**>malloc(nlevels*sizeof(TMRQuadForest*))    
    for i in range(nlevels):
        assm[i] = (<Assembler>assemblers[i]).ptr
        forst[i] = (<QuadForest>forests[i]).ptr
    TMR_CreateTACSMg(nlevels, assm, forst, &mg)
    free(assm)
    free(forst)
    return _init_Pc(mg)

def strainEnergyRefine(Assembler assembler,
                       QuadForest forest,
                       double target_err,
                       int min_refine=0, int max_refine=30):
    cdef TACSAssembler *assm = NULL
    cdef TMRQuadForest *forst = NULL
    cdef TacsScalar ans = 0.0
    assm = assembler.ptr
    forst = forest.ptr   
    ans = TMR_StrainEnergyRefine(assm, forst, target_err,
                                 min_refine, max_refine)
    return ans

def adjointRefine(Assembler coarse,
                  Assembler fine,
                  Vec adjoint,
                  QuadForest forest,
                  double target_err,
                  int min_refine=0, int max_refine=30):
    cdef TacsScalar ans = 0.0
    cdef TacsScalar adj_corr
    ans = TMR_AdjointRefine(coarse.ptr, fine.ptr,
                            adjoint.ptr, forest.ptr, target_err,
                            min_refine, max_refine, &adj_corr)
    return ans, adj_corr
